import { NextRequest } from 'next/server';
import connectDB from '@/lib/mongodb';
import User from '@/models/User';
import { authenticateRequest } from '@/lib/auth';
import { successResponse, errorResponse, unauthorizedResponse } from '@/lib/response';

export const dynamic = 'force-dynamic';

// Register/refresh the authenticated user's FCM device token for push.
export async function POST(request: NextRequest) {
  try {
    const auth = await authenticateRequest(request);
    if (!auth) return unauthorizedResponse();

    await connectDB();

    const { fcmToken } = await request.json();
    if (!fcmToken) return errorResponse('fcmToken is required');

    // Add to the per-device set rather than overwriting. A user signed in on
    // both an iPhone and an Android phone previously kept only whichever
    // registered last, so the other device silently stopped getting push.
    // `fcmToken` is still written so older app builds keep working.
    await User.findByIdAndUpdate(auth.userId, {
      $addToSet: { fcmTokens: fcmToken },
      $set: { fcmToken },
    });
    return successResponse({ ok: true }, 'Token registered');
  } catch (error) {
    console.error('Register FCM token error:', error);
    return errorResponse('Failed to register token', 500);
  }
}

// Clear the token (call on logout).
export async function DELETE(request: NextRequest) {
  try {
    const auth = await authenticateRequest(request);
    if (!auth) return unauthorizedResponse();

    await connectDB();

    // Log out should only unsubscribe the device doing the logging out. The
    // app passes its own token as ?token=...; without it (older builds) we
    // fall back to clearing everything, which is the old behaviour.
    const token = request.nextUrl.searchParams.get('token');

    if (token) {
      await User.findByIdAndUpdate(auth.userId, { $pull: { fcmTokens: token } });
      // Only clear the legacy field if it belonged to this same device.
      await User.updateOne(
        { _id: auth.userId, fcmToken: token },
        { $unset: { fcmToken: '' } }
      );
    } else {
      await User.findByIdAndUpdate(auth.userId, {
        $set: { fcmTokens: [] },
        $unset: { fcmToken: '' },
      });
    }

    return successResponse({ ok: true }, 'Token cleared');
  } catch (error) {
    console.error('Clear FCM token error:', error);
    return errorResponse('Failed to clear token', 500);
  }
}
