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

    await User.findByIdAndUpdate(auth.userId, { $set: { fcmToken } });
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
    await User.findByIdAndUpdate(auth.userId, { $unset: { fcmToken: '' } });
    return successResponse({ ok: true }, 'Token cleared');
  } catch (error) {
    console.error('Clear FCM token error:', error);
    return errorResponse('Failed to clear token', 500);
  }
}
