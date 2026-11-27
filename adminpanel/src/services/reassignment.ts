import Pharmacy from '@/models/Pharmacy';
import Patient from '@/models/Patient';
import Prescription from '@/models/Prescription';
import Quote from '@/models/Quote';
import { sendNotificationToUser, sendNotificationToPharmacy } from '@/services/notification';

// How long an assigned pharmacy has to send a quote before the request moves
// to the next nearest pharmacy. Keep in sync with the pharmacy app countdown.
export const PHARMACY_RESPONSE_MINUTES = 15;
const PHARMACY_RESPONSE_MS = PHARMACY_RESPONSE_MINUTES * 60 * 1000;

/**
 * Move every request whose assigned pharmacy hasn't sent a quote in time to
 * the next nearest pharmacy, or expire it when none is left. Safe to call
 * from many places at once: each request is claimed atomically first, so it
 * is only processed once. Returns how many requests were handled.
 */
export async function processTimedOutPrescriptions(): Promise<number> {
  const deadline = new Date(Date.now() - PHARMACY_RESPONSE_MS);
  const overdue = await Prescription.find({
    status: 'pending',
    assignedAt: { $lt: deadline },
    'nearbyPharmacies.0': { $exists: true },
  }).limit(50);

  let handled = 0;
  for (const p of overdue) {
    // Claim it: only the caller that still sees the old assignedAt wins
    const claimed = await Prescription.updateOne(
      { _id: p._id, status: 'pending', assignedAt: p.assignedAt },
      { $set: { assignedAt: new Date() } }
    );
    if (claimed.modifiedCount === 0) continue;
    handled++;

    const timedOutPharmacyId = p.nearbyPharmacies[0];

    // Mark the pharmacy as tried so it is skipped from now on
    await Quote.create({
      prescriptionId: p._id,
      patientId: p.patientId,
      pharmacyId: timedOutPharmacyId,
      items: [],
      subtotal: 0,
      deliveryFee: 0,
      totalAmount: 0,
      status: 'rejected',
      rejectionReason: `Auto-reassigned: No quote within ${PHARMACY_RESPONSE_MINUTES} minutes`,
    });

    // Deliberately NOT notifying the pharmacy that let the request time out.
    // Client feedback: telling a pharmacy that a request it ignored has moved
    // on is noise, and pharmacies were getting too many notifications. The
    // 'prescription_timeout' translation key is kept in notification-i18n.ts
    // so this can be switched back on without re-translating it.

    // Try the next nearest pharmacy (notifies it and the patient)
    const reassigned = await reassignPrescriptionToNextPharmacy(p);
    if (reassigned) continue;

    // No pharmacy left to try: expire the request
    p.nearbyPharmacies = [];
    p.status = 'expired';
    await p.save();

    try {
      const patient = await Patient.findById(p.patientId).lean() as any;
      if (patient) {
        await sendNotificationToUser(
          patient.userId.toString(),
          'prescription_expired',
          undefined,
          { prescriptionId: p._id.toString(), type: 'prescription_expired' }
        );
      }
    } catch (_) {}
  }
  return handled;
}

/**
 * Move a prescription to the next nearest approved pharmacy that has not
 * already rejected or been accepted for it. Notifies the newly assigned
 * pharmacy and the patient. Returns false when no untried pharmacy is left,
 * in which case the prescription is NOT modified — the caller decides the
 * fallback (keep pending, expire, etc).
 */
export async function reassignPrescriptionToNextPharmacy(prescription: any): Promise<boolean> {
  // Pharmacies already tried for this prescription
  const triedQuotes = await Quote.find({
    prescriptionId: prescription._id,
    status: { $in: ['rejected', 'accepted'] },
  }).lean() as any[];

  const triedIds = triedQuotes.map((q: any) => q.pharmacyId.toString());

  // Find next nearest untried approved pharmacy
  let nextPharmacy = null;

  if (prescription.deliveryAddress?.location?.coordinates?.length === 2) {
    nextPharmacy = await Pharmacy.findOne({
      _id: { $nin: triedIds },
      approvalStatus: 'approved',
      location: {
        $near: {
          $geometry: {
            type: 'Point',
            coordinates: prescription.deliveryAddress.location.coordinates,
          },
        },
      },
    }).lean() as any;
  } else {
    nextPharmacy = await Pharmacy.findOne({
      _id: { $nin: triedIds },
      approvalStatus: 'approved',
    }).lean() as any;
  }

  if (!nextPharmacy) {
    return false;
  }

  prescription.nearbyPharmacies = [nextPharmacy._id];
  prescription.assignedAt = new Date();
  prescription.status = 'pending';
  await prescription.save();

  // Notify the newly assigned pharmacy
  try {
    await sendNotificationToPharmacy(
      nextPharmacy._id.toString(),
      'prescription_request',
      undefined,
      { prescriptionId: prescription._id.toString(), type: 'prescription_request' }
    );
  } catch (_) {}

  // Notify the patient
  try {
    const patient = await Patient.findById(prescription.patientId).lean() as any;
    if (patient) {
      await sendNotificationToUser(
        patient.userId.toString(),
        'prescription_reassigned',
        undefined,
        { prescriptionId: prescription._id.toString(), type: 'prescription_reassigned' }
      );
    }
  } catch (_) {}

  return true;
}
