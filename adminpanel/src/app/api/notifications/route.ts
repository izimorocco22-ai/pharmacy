import { NextRequest } from 'next/server';
import connectDB from '@/lib/mongodb';
import Notification from '@/models/Notification';
import User from '@/models/User';
import { translateNotification, normalizeLang } from '@/services/notification-i18n';
import { authenticateRequest } from '@/lib/auth';
import { successResponse, errorResponse, unauthorizedResponse } from '@/lib/response';

export const dynamic = 'force-dynamic';

// List the authenticated user's notifications (newest first) + unread count.
export async function GET(request: NextRequest) {
  try {
    const auth = await authenticateRequest(request);
    if (!auth) return unauthorizedResponse();

    await connectDB();

    const stored = await Notification.find({ userId: auth.userId })
      .sort({ createdAt: -1 })
      .limit(100)
      .lean();

    // Re-render in the language the user is using RIGHT NOW. The stored
    // title/body are only a snapshot of the language at send time, so without
    // this a user who switches language keeps seeing their old history in the
    // previous one. Notifications saved before localization have no key and
    // are passed through untouched.
    const user = await User.findById(auth.userId).select('language').lean() as any;
    const lang = normalizeLang(user?.language);
    const notifications = stored.map((n: any) =>
      n.key ? { ...n, ...translateNotification(n.key, lang, n.params) } : n
    );

    const unreadCount = await Notification.countDocuments({
      userId: auth.userId,
      isRead: false,
    });

    return successResponse({ notifications, unreadCount });
  } catch (error) {
    console.error('Get notifications error:', error);
    return errorResponse('Failed to fetch notifications', 500);
  }
}
