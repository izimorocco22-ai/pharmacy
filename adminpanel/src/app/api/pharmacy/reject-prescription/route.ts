import { NextRequest } from 'next/server';
import connectDB from '@/lib/mongodb';
import Prescription from '@/models/Prescription';
import Pharmacy from '@/models/Pharmacy';
import Quote from '@/models/Quote';
import { authenticateRequest } from '@/lib/auth';
import { successResponse, errorResponse, unauthorizedResponse } from '@/lib/response';
import { sendNotificationToUser } from '@/services/notification';
import Patient from '@/models/Patient';

export const dynamic = 'force-dynamic';

export async function POST(request: NextRequest) {
  try {
    const auth = await authenticateRequest(request);
    if (!auth || auth.role !== 'pharmacy') return unauthorizedResponse();

    await connectDB();

    const { prescriptionId, reason } = await request.json();
    if (!prescriptionId) return errorResponse('prescriptionId is required');

    // Get current pharmacy
    const pharmacy = await Pharmacy.findOne({ userId: auth.userId }).lean() as any;
    if (!pharmacy) return errorResponse('Pharmacy not found', 404);

    const prescription = await Prescription.findById(prescriptionId);
    if (!prescription) return errorResponse('Prescription not found', 404);

    // Create a rejected quote record so this pharmacy is excluded from future reassignments
    await Quote.create({
      prescriptionId: prescription._id,
      patientId: prescription.patientId,
      pharmacyId: pharmacy._id,
      items: [],
      subtotal: 0,
      deliveryFee: 0,
      totalAmount: 0,
      status: 'rejected',
      rejectionReason: reason || 'Rejected by pharmacy',
    });

    // Get all pharmacies already tried
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

    if (nextPharmacy) {
      prescription.nearbyPharmacies = [nextPharmacy._id];
      prescription.assignedAt = new Date();
      prescription.status = 'pending';
      await prescription.save();

      // Notify patient
      try {
        const patient = await Patient.findById(prescription.patientId).lean() as any;
        if (patient) {
          await sendNotificationToUser(
            patient.userId.toString(),
            'Prescription Reassigned',
            'Your prescription has been sent to another nearby pharmacy.',
            { prescriptionId: prescription._id.toString(), type: 'prescription_reassigned' }
          );
        }
      } catch (_) {}

      return successResponse({ reassigned: true }, 'Prescription rejected and reassigned to next pharmacy');
    } else {
      prescription.nearbyPharmacies = [];
      prescription.status = 'pending';
      await prescription.save();

      return successResponse({ reassigned: false }, 'Prescription rejected. No more pharmacies available.');
    }
  } catch (error) {
    console.error('Reject prescription error:', error);
    return errorResponse('Failed to reject prescription', 500);
  }
}
