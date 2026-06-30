import { NextRequest } from 'next/server';
import connectDB from '@/lib/mongodb';
import Prescription from '@/models/Prescription';
import Pharmacy from '@/models/Pharmacy';
import Patient from '@/models/Patient';
import { authenticateRequest } from '@/lib/auth';
import { successResponse, errorResponse, unauthorizedResponse } from '@/lib/response';
import { sendNotificationToPharmacy } from '@/services/notification';

export async function POST(request: NextRequest) {
  try {
    const auth = await authenticateRequest(request);
    if (!auth || auth.role !== 'patient') {
      return unauthorizedResponse();
    }

    await connectDB();

    const body = await request.json();
    const { prescriptionId, deliveryAddress } = body;

    if (!prescriptionId || !deliveryAddress) {
      return errorResponse('prescriptionId and deliveryAddress are required');
    }

    const patient = await Patient.findOne({ userId: auth.userId });
    if (!patient) return errorResponse('Patient profile not found', 404);

    const prescription = await Prescription.findOne({
      _id: prescriptionId,
      patientId: patient._id,
    });
    if (!prescription) return errorResponse('Prescription not found', 404);

    const addressText = deliveryAddress.address || deliveryAddress.label || 'Delivery address';
    const rawCoords = deliveryAddress.coordinates || deliveryAddress.location?.coordinates;
    const hasValidCoords = Array.isArray(rawCoords) && rawCoords.length === 2 &&
      rawCoords.every((c: any) => typeof c === 'number') &&
      (rawCoords[0] !== 0 || rawCoords[1] !== 0);
    const coordinates: [number, number] = hasValidCoords ? [rawCoords[0], rawCoords[1]] : [0, 0];

    // Update prescription delivery address
    if (hasValidCoords) {
      prescription.deliveryAddress = {
        address: addressText,
        location: { type: 'Point', coordinates },
      };
    } else {
      prescription.set('deliveryAddress', { address: addressText }, { strict: false });
    }

    // Find single nearest approved pharmacy within 100km
    let nearestPharmacy = null;

    if (hasValidCoords) {
      nearestPharmacy = await Pharmacy.findOne({
        location: {
          $near: {
            $geometry: { type: 'Point', coordinates },
            $maxDistance: 100000,
          },
        },
        approvalStatus: 'approved',
      }).lean() as any;
    }

    // Fallback: absolute nearest approved pharmacy
    if (!nearestPharmacy) {
      nearestPharmacy = await Pharmacy.findOne({ approvalStatus: 'approved' }).lean() as any;
    }

    if (nearestPharmacy) {
      prescription.nearbyPharmacies = [nearestPharmacy._id];
      prescription.assignedAt = new Date();
    }

    prescription.status = 'pending';
    await prescription.save();

    // Notify the assigned pharmacy that a new request is waiting for a quote.
    if (nearestPharmacy) {
      try {
        await sendNotificationToPharmacy(
          nearestPharmacy._id.toString(),
          'New Prescription Request',
          'A new prescription request is waiting for your quote.',
          { prescriptionId: prescription._id.toString(), type: 'prescription_request' }
        );
      } catch (_) {}
    }

    return successResponse(
      {
        order: {
          _id: prescription._id,
          id: prescription._id,
          orderNumber: `REQ-${prescription._id.toString().slice(-6).toUpperCase()}`,
          prescriptionId: prescription._id,
          status: 'pending',
          deliveryAddress: prescription.deliveryAddress,
          nearbyPharmaciesCount: nearestPharmacy ? 1 : 0,
        },
      },
      'Order created successfully',
      201
    );
  } catch (error: any) {
    console.error('Create order error:', error);
    return errorResponse('Failed to create order', 500);
  }
}
