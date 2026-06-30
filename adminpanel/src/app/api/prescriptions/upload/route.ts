import { NextRequest } from 'next/server';
import connectDB from '@/lib/mongodb';
import Prescription from '@/models/Prescription';
import Pharmacy from '@/models/Pharmacy';
import Patient from '@/models/Patient';
import { authenticateRequest } from '@/lib/auth';
import { successResponse, errorResponse, unauthorizedResponse } from '@/lib/response';
import { sendNotificationToUser, sendNotificationToPharmacy } from '@/services/notification';

export async function POST(request: NextRequest) {
  try {
    const auth = await authenticateRequest(request);
    if (!auth || auth.role !== 'patient') {
      return unauthorizedResponse();
    }

    await connectDB();

    const body = await request.json();
    const { imageUrl, imagePublicId, address, coordinates, medicines } = body;

    if (!imageUrl && (!medicines || medicines.length === 0)) {
      return errorResponse('Either image URL or medicines list is required');
    }

    const patient = await Patient.findOne({ userId: auth.userId });
    if (!patient) {
      return errorResponse('Patient profile not found', 404);
    }

    const prescriptionData: any = {
      patientId: patient._id,
      imageUrl: imageUrl || '',
      status: 'pending',
    };

    if (imagePublicId) prescriptionData.imagePublicId = imagePublicId;
    if (medicines && medicines.length > 0) prescriptionData.medicines = medicines;

    let nearbyPharmaciesCount = 0;

    if (address && Array.isArray(coordinates) && coordinates.length === 2 && coordinates.every((c: any) => typeof c === 'number')) {
      prescriptionData.deliveryAddress = {
        address,
        location: {
          type: 'Point',
          coordinates, // [longitude, latitude]
        },
      };

      // Find the single nearest approved pharmacy within 100km
      let nearestPharmacy = await Pharmacy.findOne({
        location: {
          $near: {
            $geometry: { type: 'Point', coordinates },
            $maxDistance: 100000, // 100km
          },
        },
        approvalStatus: 'approved',
      }).lean();

      // Fallback: if none within 100km, get the absolute nearest
      if (!nearestPharmacy) {
        nearestPharmacy = await Pharmacy.findOne({
          approvalStatus: 'approved',
          location: {
            $near: {
              $geometry: { type: 'Point', coordinates },
            },
          },
        }).lean();
      }

      if (nearestPharmacy) {
        prescriptionData.nearbyPharmacies = [(nearestPharmacy as any)._id];
        nearbyPharmaciesCount = 1;
      }
    } else {
      // No coordinates — assign to the first approved pharmacy
      const pharmacy = await Pharmacy.findOne({ approvalStatus: 'approved' }).lean();
      if (pharmacy) {
        prescriptionData.nearbyPharmacies = [(pharmacy as any)._id];
        nearbyPharmaciesCount = 1;
      }
    }

    const prescription = await Prescription.create(prescriptionData);

    // Notify the patient that their request was submitted, and alert the
    // pharmacy it was assigned to so they can send a quote.
    try {
      await sendNotificationToUser(
        auth.userId,
        'Request Submitted',
        'Your prescription request was submitted. We are finding a pharmacy for you.',
        { prescriptionId: prescription._id.toString(), type: 'prescription_submitted' }
      );
      const assignedPharmacyId = prescription.nearbyPharmacies?.[0]?.toString();
      if (assignedPharmacyId) {
        await sendNotificationToPharmacy(
          assignedPharmacyId,
          'New Prescription Request',
          'A new prescription request is waiting for your quote.',
          { prescriptionId: prescription._id.toString(), type: 'prescription_request' }
        );
      }
    } catch (_) {}

    return successResponse(
      {
        prescription: {
          _id: prescription._id,
          imageUrl: prescription.imageUrl,
          status: prescription.status,
          nearbyPharmaciesCount,
          assignedToPharmacy: nearbyPharmaciesCount === 1,
        },
      },
      'Prescription uploaded successfully',
      201
    );
  } catch (error: any) {
    console.error('Upload prescription error:', error);
    return errorResponse('Failed to upload prescription', 500);
  }
}
