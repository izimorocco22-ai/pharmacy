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

    const { fcmToken, language } = await request.json();

    // The app also calls this with only { language } when the user switches
    // language, so a body carrying either one is valid.
    if (!fcmToken && !language) {
      return errorResponse('fcmToken or language is required');
    }

    const set: Record<string, any> = {};
    // Persist the UI language so push notifications can be sent in it. Ignore
    // anything we do not translate rather than storing a junk value the enum
    // would then reject on save.
    if (language && ['en', 'fr', 'ar'].includes(language)) set.language = language;

    if (fcmToken) {
      // Add to the per-device set rather than overwriting. A user signed in on
      // both an iPhone and an Android phone previously kept only whichever
      // registered last, so the other device silently stopped getting push.
      // `fcmToken` is still written so older app builds keep working.
      set.fcmToken = fcmToken;
      await User.findByIdAndUpdate(auth.userId, {
        $addToSet: { fcmTokens: fcmToken },
        $set: set,
      });
    } else {
      await User.findByIdAndUpdate(auth.userId, { $set: set });
    }

    return successResponse({ ok: true }, fcmToken ? 'Token registered' : 'Language saved');
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
