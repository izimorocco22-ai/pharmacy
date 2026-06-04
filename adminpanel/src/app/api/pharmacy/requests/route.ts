import { NextRequest } from 'next/server';
import connectDB from '@/lib/mongodb';
import Prescription from '@/models/Prescription';
import Pharmacy from '@/models/Pharmacy';
import Patient from '@/models/Patient';
import User from '@/models/User';
import Quote from '@/models/Quote';
import { authenticateRequest } from '@/lib/auth';
import { successResponse, errorResponse, unauthorizedResponse } from '@/lib/response';

export const dynamic = 'force-dynamic';

export async function GET(request: NextRequest) {
  try {
    const auth = await authenticateRequest(request);
    if (!auth || auth.role !== 'pharmacy') {
      return unauthorizedResponse();
    }

    await connectDB();

    const pharmacy = await Pharmacy.findOne({ userId: auth.userId }).lean() as any;
    if (!pharmacy) {
      return errorResponse('Pharmacy profile not found', 404);
    }

    // Auto-check for timeouts before returning requests
    const now = new Date();
    const oneHourAgo = new Date(now.getTime() - 60 * 60 * 1000);

    const timedOutPrescriptions = await Prescription.find({
      nearbyPharmacies: pharmacy._id,
      status: 'pending',
      assignedAt: { $lt: oneHourAgo },
    });

    if (timedOutPrescriptions.length > 0) {
      for (const p of timedOutPrescriptions) {
        // Exclude this pharmacy by creating a rejected quote
        await Quote.create({
          prescriptionId: p._id,
          patientId: p.patientId,
          pharmacyId: pharmacy._id,
          items: [],
          subtotal: 0,
          deliveryFee: 0,
          totalAmount: 0,
          status: 'rejected',
          rejectionReason: 'Auto-cancelled: Request timed out (1 hour limit)',
        });

        // Try to reassign to next pharmacy
        const triedQuotes = await Quote.find({
          prescriptionId: p._id,
          status: { $in: ['rejected', 'accepted'] },
        }).lean() as any[];
        const triedIds = triedQuotes.map((q: any) => q.pharmacyId.toString());

        let nextPharmacy = null;
        if (p.deliveryAddress?.location?.coordinates?.length === 2) {
          nextPharmacy = await Pharmacy.findOne({
            _id: { $nin: triedIds },
            approvalStatus: 'approved',
            location: {
              $near: {
                $geometry: { type: 'Point', coordinates: p.deliveryAddress.location.coordinates },
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
          p.nearbyPharmacies = [nextPharmacy._id];
          p.assignedAt = new Date();
        } else {
          p.nearbyPharmacies = [];
          p.status = 'expired'; // Or keep pending but empty
        }
        await p.save();
      }
    }

    // Show pending, quoted and confirmed prescriptions assigned to this pharmacy
    const prescriptions = await Prescription.find({
      nearbyPharmacies: pharmacy._id,
      status: { $in: ['pending', 'quoted', 'accepted'] },
    })
      .sort({ createdAt: -1 })
      .limit(50)
      .lean() as any[];

    // Fetch patient user info separately to avoid nested populate crashes
    const formatted = await Promise.all(
      prescriptions.map(async (p: any) => {
        let patientName = 'Unknown Patient';
        let patientPhone = '';
        let patientEmail = '';

        try {
          if (p.patientId) {
            const patient = await Patient.findById(p.patientId).lean() as any;
            if (patient?.userId) {
              const user = await User.findById(patient.userId)
                .select('fullName phone email')
                .lean() as any;
              if (user) {
                patientName = user.fullName || 'Unknown Patient';
                patientPhone = user.phone || '';
                patientEmail = user.email || '';
              }
            }
          }
        } catch (_) {
          // keep defaults if patient lookup fails
        }

        const deliveryAddress = p.deliveryAddress?.address || 'Address not provided';
        const deliveryCoords = p.deliveryAddress?.location?.coordinates;

        let distance = null;
        try {
          if (
            deliveryCoords &&
            Array.isArray(deliveryCoords) &&
            deliveryCoords.length === 2 &&
            pharmacy.location?.coordinates?.length === 2
          ) {
            distance = calculateDistance(pharmacy.location.coordinates, deliveryCoords);
          }
        } catch (_) {}

        let existingQuote = null;
        try {
          const q = await Quote.findOne({
            prescriptionId: p._id,
            pharmacyId: pharmacy._id,
          }).lean() as any;
          if (q) {
            existingQuote = {
              id: q._id,
              items: q.items,
              subtotal: q.subtotal,
              deliveryFee: q.deliveryFee,
              totalAmount: q.totalAmount,
              status: q.status,
            };
          }
        } catch (_) {}

        return {
          id: p._id,
          imageUrl: p.imageUrl || '',
          medicines: p.medicines || [],
          patientName,
          patientPhone,
          patientEmail,
          deliveryAddress,
          deliveryCoordinates: deliveryCoords || null,
          distance,
          status: p.status,
          existingQuote,
          createdAt: p.createdAt,
          assignedAt: p.assignedAt || p.createdAt,
          expiresAt: p.expiresAt,
        };
      })
    );

    return successResponse({ prescriptions: formatted });
  } catch (error: any) {
    console.error('Get requests error:', error);
    return errorResponse('Failed to fetch requests', 500);
  }
}

function calculateDistance(coords1: number[], coords2: number[]): number {
  const R = 6371;
  const dLat = toRad(coords2[1] - coords1[1]);
  const dLon = toRad(coords2[0] - coords1[0]);
  const lat1 = toRad(coords1[1]);
  const lat2 = toRad(coords2[1]);
  const a =
    Math.sin(dLat / 2) * Math.sin(dLat / 2) +
    Math.sin(dLon / 2) * Math.sin(dLon / 2) * Math.cos(lat1) * Math.cos(lat2);
  const c = 2 * Math.atan2(Math.sqrt(a), Math.sqrt(1 - a));
  return Math.round(R * c * 10) / 10;
}

function toRad(value: number): number {
  return (value * Math.PI) / 180;
}
