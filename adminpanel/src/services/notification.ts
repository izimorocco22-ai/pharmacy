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

    // Send FCM notification
    await admin.messaging().send({
      token: user.fcmToken,
      notification: { title, body },
      data: data || {},
    });
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
    const users = await User.find({ _id: { $in: userIds }, fcmToken: { $exists: true } });

    // Save notifications
    const notifications = userIds.map((userId) => ({
      userId,
      title,
      body,
      type: data?.type || 'general',
      data,
    }));
    await Notification.insertMany(notifications);

    // Send FCM notifications
    const tokens = users.map((u) => u.fcmToken).filter(Boolean) as string[];
    if (tokens.length > 0) {
      await admin.messaging().sendEachForMulticast({
        tokens,
        notification: { title, body },
        data: data || {},
      });
    }
  } catch (error) {
    console.error('Send notifications error:', error);
  }
}
