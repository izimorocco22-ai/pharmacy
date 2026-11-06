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
        clickAction: 'FLUTTER_NOTIFICATION_CLICK',
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
 * rotated. Leaving it on the user keeps every later send failing, so drop it.
 */
async function pruneTokenIfDead(userId: string, error: any) {
  const code = error?.errorInfo?.code || error?.code;
  if (
    code === 'messaging/registration-token-not-registered' ||
    code === 'messaging/invalid-registration-token' ||
    code === 'messaging/invalid-argument'
  ) {
    await User.findByIdAndUpdate(userId, { $unset: { fcmToken: '' } });
  }
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

    // Get user FCM token
    const user = await User.findById(userId);
    if (!user || !user.fcmToken) {
      return;
    }

    try {
      await admin.messaging().send({
        token: user.fcmToken,
        ...buildPushPayload(title, body, data),
      });
    } catch (sendError) {
      console.error('FCM send error:', sendError);
      await pruneTokenIfDead(userId, sendError);
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

    const users = await User.find({
      _id: { $in: userIds },
      fcmToken: { $exists: true, $ne: null },
    });

    const recipients = users
      .filter((u) => !!u.fcmToken)
      .map((u) => ({ userId: u._id.toString(), token: u.fcmToken as string }));
    if (recipients.length === 0) return;

    const response = await admin.messaging().sendEachForMulticast({
      tokens: recipients.map((r) => r.token),
      ...buildPushPayload(title, body, data),
    });

    // Drop tokens APNs/FCM reported as dead so they stop failing forever.
    await Promise.all(
      response.responses.map((r, i) =>
        r.success ? null : pruneTokenIfDead(recipients[i].userId, r.error)
      )
    );
  } catch (error) {
    console.error('Send notifications error:', error);
  }
}
