import admin from 'firebase-admin';
import User from '@/models/User';
import Patient from '@/models/Patient';
import Pharmacy from '@/models/Pharmacy';
import Rider from '@/models/Rider';
import Notification from '@/models/Notification';

// Initialize Firebase Admin (optional - only if credentials are provided)
let firebaseInitialized = false;
if (!admin.apps.length && process.env.FIREBASE_PROJECT_ID) {
  try {
    admin.initializeApp({
      credential: admin.credential.cert({
        projectId: process.env.FIREBASE_PROJECT_ID,
        privateKey: process.env.FIREBASE_PRIVATE_KEY?.replace(/\\n/g, '\n'),
        clientEmail: process.env.FIREBASE_CLIENT_EMAIL,
      } as admin.ServiceAccount),
    });
    firebaseInitialized = true;
  } catch (error) {
    console.warn('Firebase Admin initialization skipped:', error);
  }
}

/** FCM rejects the whole message unless every data value is a string. */
function stringifyData(data?: Record<string, any>): Record<string, string> {
  const out: Record<string, string> = {};
  for (const [key, value] of Object.entries(data || {})) {
    if (value !== undefined && value !== null) out[key] = String(value);
  }
  return out;
}

/**
 * Builds the cross-platform FCM payload.
 *
 * The `apns` block is what makes iOS work. Without it APNs receives the
 * message at the default priority (5), which lets the system delay or drop it
 * when the device is locked or low on battery, and it arrives with no sound.
 * `apns-push-type` is mandatory for APNs on iOS 13+ — messages sent without it
 * are rejected outright.
 */
function buildPushPayload(
  title: string,
  body: string,
  data?: Record<string, any>
) {
  return {
    notification: { title, body },
    data: stringifyData(data),
    android: {
      // High priority so the notification is delivered immediately even
      // when the app is closed and the device is dozing.
      priority: 'high' as const,
      notification: {
        channelId: 'ordogo_default',
        // Deliberately NO clickAction. When click_action is set, the FCM SDK
        // builds the tap PendingIntent as new Intent(click_action) instead of
        // the launcher intent — and it never checks that anything resolves it.
        // Since no app declares a matching intent filter, every notification
        // FCM displayed itself (app backgrounded or closed) was shown but did
        // nothing when tapped. Leaving it unset makes FCM fall back to
        // getLaunchIntentForPackage(), which opens the app and lets
        // getInitialMessage()/onMessageOpenedApp() route the tap.
      },
    },
    apns: {
      headers: {
        'apns-priority': '10',
        'apns-push-type': 'alert',
      },
      payload: {
        aps: {
          alert: { title, body },
          sound: 'default',
        },
      },
    },
  };
}

/**
 * A token is permanently dead once the app is uninstalled or the token is
 * rotated. Leaving it on the user keeps every later send failing.
 */
function isDeadTokenError(error: any): boolean {
  const code = error?.errorInfo?.code || error?.code;
  return (
    code === 'messaging/registration-token-not-registered' ||
    code === 'messaging/invalid-registration-token' ||
    code === 'messaging/invalid-argument'
  );
}

/** Every device token this user is signed in on, newest field first. */
function tokensOf(user: { fcmTokens?: string[]; fcmToken?: string }): string[] {
  const all = [...(user.fcmTokens || []), ...(user.fcmToken ? [user.fcmToken] : [])];
  return Array.from(new Set(all.filter(Boolean)));
}

/** Removes dead tokens from both the array and the legacy single field. */
async function pruneTokens(userId: string, dead: string[]) {
  if (dead.length === 0) return;
  await User.findByIdAndUpdate(userId, { $pull: { fcmTokens: { $in: dead } } });
  await User.updateOne(
    { _id: userId, fcmToken: { $in: dead } },
    { $unset: { fcmToken: '' } }
  );
}

export async function sendNotificationToUser(
  userId: string,
  title: string,
  body: string,
  data?: Record<string, any>
) {
  try {
    // Save notification to database
    await Notification.create({
      userId,
      title,
      body,
      type: data?.type || 'general',
      data,
    });

    // Only send FCM notification if Firebase is initialized
    if (!firebaseInitialized) {
      console.log('Firebase not initialized, skipping push notification');
      return;
    }

    // Send to every device this user is signed in on — e.g. an iPhone and an
    // Android phone on the same account must both get the notification.
    const user = await User.findById(userId);
    if (!user) return;

    const tokens = tokensOf(user);
    if (tokens.length === 0) return;

    try {
      const response = await admin.messaging().sendEachForMulticast({
        tokens,
        ...buildPushPayload(title, body, data),
      });

      const dead: string[] = [];
      response.responses.forEach((r, i) => {
        if (r.success) return;
        console.error(`FCM send error for token ${i}:`, r.error);
        if (isDeadTokenError(r.error)) dead.push(tokens[i]);
      });
      await pruneTokens(userId, dead);
    } catch (sendError) {
      console.error('FCM send error:', sendError);
    }
  } catch (error) {
    console.error('Send notification error:', error);
  }
}

/**
 * Notifications are stored against a User._id, but order/quote/prescription
 * documents reference the role-specific doc id (Patient._id, Pharmacy._id,
 * Rider._id). These helpers resolve that role doc to its owning userId so the
 * notification reaches the right account.
 */
export async function sendNotificationToPatient(
  patientId: string,
  title: string,
  body: string,
  data?: Record<string, any>
) {
  try {
    const patient = await Patient.findById(patientId).select('userId');
    if (!patient) return;
    await sendNotificationToUser(patient.userId.toString(), title, body, data);
  } catch (error) {
    console.error('sendNotificationToPatient error:', error);
  }
}

export async function sendNotificationToPharmacy(
  pharmacyId: string,
  title: string,
  body: string,
  data?: Record<string, any>
) {
  try {
    const pharmacy = await Pharmacy.findById(pharmacyId).select('userId');
    if (!pharmacy) return;
    await sendNotificationToUser(pharmacy.userId.toString(), title, body, data);
  } catch (error) {
    console.error('sendNotificationToPharmacy error:', error);
  }
}

export async function sendNotificationToRider(
  riderId: string,
  title: string,
  body: string,
  data?: Record<string, any>
) {
  try {
    const rider = await Rider.findById(riderId).select('userId');
    if (!rider) return;
    await sendNotificationToUser(rider.userId.toString(), title, body, data);
  } catch (error) {
    console.error('sendNotificationToRider error:', error);
  }
}

export async function sendNotificationToPharmacies(
  userIds: string[],
  title: string,
  body: string,
  data?: Record<string, any>
) {
  try {
    // Save notifications
    const notifications = userIds.map((userId) => ({
      userId,
      title,
      body,
      type: data?.type || 'general',
      data,
    }));
    await Notification.insertMany(notifications);

    // Only send FCM notifications if Firebase is initialized — calling
    // admin.messaging() without credentials throws and would lose the batch.
    if (!firebaseInitialized) {
      console.log('Firebase not initialized, skipping push notifications');
      return;
    }

    const users = await User.find({ _id: { $in: userIds } });

    // One entry per device, so a user signed in on two phones gets both.
    const recipients = users.flatMap((u) =>
      tokensOf(u).map((token) => ({ userId: u._id.toString(), token }))
    );
    if (recipients.length === 0) return;

    const response = await admin.messaging().sendEachForMulticast({
      tokens: recipients.map((r) => r.token),
      ...buildPushPayload(title, body, data),
    });

    // Drop tokens APNs/FCM reported as dead so they stop failing forever.
    const deadByUser = new Map<string, string[]>();
    response.responses.forEach((r, i) => {
      if (r.success) return;
      console.error(`FCM multicast error for ${recipients[i].token}:`, r.error);
      if (!isDeadTokenError(r.error)) return;
      const { userId, token } = recipients[i];
      deadByUser.set(userId, [...(deadByUser.get(userId) || []), token]);
    });
    await Promise.all(
      [...deadByUser.entries()].map(([userId, dead]) => pruneTokens(userId, dead))
    );
  } catch (error) {
    console.error('Send notifications error:', error);
  }
}
