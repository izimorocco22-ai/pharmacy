import { NextRequest } from 'next/server';
import connectDB from '@/lib/mongodb';
import Prescription from '@/models/Prescription';
import Pharmacy from '@/models/Pharmacy';
import Settings from '@/models/Settings';
import { authenticateRequest } from '@/lib/auth';
import { successResponse, errorResponse, unauthorizedResponse } from '@/lib/response';

export const dynamic = 'force-dynamic';

function toRad(value: number): number {
  return (value * Math.PI) / 180;
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

// Returns the commission rate and the distance-based delivery fee for a
// prescription, so the pharmacy can preview the fee breakdown before sending a
// quote. Uses the exact same calculation as /pharmacy/send-quote.
export async function GET(request: NextRequest) {
  try {
    const auth = await authenticateRequest(request);
    if (!auth || auth.role !== 'pharmacy') return unauthorizedResponse();

    await connectDB();

    const { searchParams } = new URL(request.url);
    const prescriptionId = searchParams.get('prescriptionId');
    if (!prescriptionId) return errorResponse('prescriptionId is required');

    const settings = (await Settings.findOne().lean()) as any;
    const deliveryFeePerKm = settings?.deliveryFee ?? 20;
    const commissionRate = settings?.commissionRate ?? 15;
    const minCommission = settings?.minCommission ?? 500;

    const pharmacy = (await Pharmacy.findOne({ userId: auth.userId }).lean()) as any;
    if (!pharmacy) return errorResponse('Pharmacy not found', 404);

    const prescription = (await Prescription.findById(prescriptionId).lean()) as any;
    if (!prescription) return errorResponse('Prescription not found', 404);

    let deliveryFee = deliveryFeePerKm; // fallback: 1km minimum
    try {
      const deliveryCoords = prescription.deliveryAddress?.location?.coordinates;
      const pharmacyCoords = pharmacy.location?.coordinates;
      if (
        Array.isArray(deliveryCoords) && deliveryCoords.length === 2 &&
        Array.isArray(pharmacyCoords) && pharmacyCoords.length === 2
      ) {
        const distance = calculateDistance(pharmacyCoords, deliveryCoords);
        deliveryFee = parseFloat((distance * deliveryFeePerKm).toFixed(2));
        if (deliveryFee < deliveryFeePerKm) deliveryFee = deliveryFeePerKm;
      }
    } catch (_) {}

    return successResponse({ commissionRate, minCommission, deliveryFee, deliveryFeePerKm });
  } catch (error) {
    console.error('Quote preview error:', error);
    return errorResponse('Failed to compute quote preview', 500);
  }
}
