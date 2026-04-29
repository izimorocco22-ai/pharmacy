import { NextRequest } from 'next/server';
import connectDB from '@/lib/mongodb';
import Quote from '@/models/Quote';
import Prescription from '@/models/Prescription';
import Pharmacy from '@/models/Pharmacy';
import Settings from '@/models/Settings';
import { authenticateRequest } from '@/lib/auth';
import { successResponse, errorResponse, unauthorizedResponse } from '@/lib/response';
import { sendNotificationToUser } from '@/services/notification';

export const dynamic = 'force-dynamic';

// GET: fetch existing quote for a prescription by this pharmacy
export async function GET(request: NextRequest) {
  try {
    const auth = await authenticateRequest(request);
    if (!auth || auth.role !== 'pharmacy') return unauthorizedResponse();

    await connectDB();

    const { searchParams } = new URL(request.url);
    const prescriptionId = searchParams.get('prescriptionId');
    if (!prescriptionId) return errorResponse('prescriptionId is required');

    const pharmacy = await Pharmacy.findOne({ userId: auth.userId }).lean() as any;
    if (!pharmacy) return errorResponse('Pharmacy not found', 404);

    const quote = await Quote.findOne({
      prescriptionId,
      pharmacyId: pharmacy._id,
    }).lean() as any;

    if (!quote) return successResponse({ quote: null });

    return successResponse({
      quote: {
        id: quote._id,
        items: quote.items,
        subtotal: quote.subtotal,
        commissionRate: quote.commissionRate,
        commissionAmount: quote.commissionAmount,
        deliveryFee: quote.deliveryFee,
        totalAmount: quote.totalAmount,
        status: quote.status,
      },
    });
  } catch (error) {
    console.error('Get quote error:', error);
    return errorResponse('Failed to fetch quote', 500);
  }
}

// POST: create or update quote
export async function POST(request: NextRequest) {
  try {
    const auth = await authenticateRequest(request);
    if (!auth || auth.role !== 'pharmacy') return unauthorizedResponse();

    await connectDB();

    const body = await request.json();
    const { prescriptionId, items: rawItems, directTotal } = body;

    // Support direct total mode: pharmacy sends a single total amount
    const items = directTotal != null
      ? [{ medicineName: 'Total', quantity: 1, unitPrice: Number(directTotal), totalPrice: Number(directTotal) }]
      : rawItems;

    if (!prescriptionId || !items || items.length === 0) {
      return errorResponse('Prescription ID and items are required');
    }

    const pharmacy = await Pharmacy.findOne({ userId: auth.userId });
    if (!pharmacy) return errorResponse('Pharmacy profile not found', 404);

    const prescription = await Prescription.findById(prescriptionId);
    if (!prescription) return errorResponse('Prescription not found', 404);

    if (!['pending', 'quoted'].includes(prescription.status)) {
      return errorResponse('Prescription is no longer available');
    }

    // Fetch admin settings for delivery fee per km and commission
    const settings = await Settings.findOne().lean() as any;
    const deliveryFeePerKm = settings?.deliveryFee ?? 20;
    const commissionRate = settings?.commissionRate ?? 0;

    // Calculate distance-based delivery fee
    let deliveryFee = deliveryFeePerKm; // fallback: 1km minimum
    try {
      const pharmacyDoc = await Pharmacy.findOne({ userId: auth.userId }).lean() as any;
      const deliveryCoords = prescription.deliveryAddress?.location?.coordinates;
      const pharmacyCoords = pharmacyDoc?.location?.coordinates;

      if (
        deliveryCoords && Array.isArray(deliveryCoords) && deliveryCoords.length === 2 &&
        pharmacyCoords && Array.isArray(pharmacyCoords) && pharmacyCoords.length === 2
      ) {
        const distance = calculateDistance(pharmacyCoords, deliveryCoords);
        deliveryFee = parseFloat((distance * deliveryFeePerKm).toFixed(2));
        if (deliveryFee < deliveryFeePerKm) deliveryFee = deliveryFeePerKm; // minimum 1km charge
      }
    } catch (_) {}

    const subtotal = items.reduce((sum: number, item: any) => sum + item.totalPrice, 0);
    const commissionAmount = parseFloat(((subtotal * commissionRate) / 100).toFixed(2));
    const totalAmount = parseFloat((subtotal + commissionAmount + deliveryFee).toFixed(2));

    // Check if quote already exists from this pharmacy
    const existingQuote = await Quote.findOne({
      prescriptionId: prescription._id,
      pharmacyId: pharmacy._id,
    });

    let quote;
    let isEdit = false;

    if (existingQuote) {
      existingQuote.items = items;
      existingQuote.subtotal = subtotal;
      existingQuote.commissionRate = commissionRate;
      existingQuote.commissionAmount = commissionAmount;
      existingQuote.deliveryFee = deliveryFee;
      existingQuote.totalAmount = totalAmount;
      existingQuote.status = 'pending';
      await existingQuote.save();
      quote = existingQuote;
      isEdit = true;
    } else {
      quote = await Quote.create({
        prescriptionId: prescription._id,
        pharmacyId: pharmacy._id,
        patientId: prescription.patientId,
        items,
        subtotal,
        commissionRate,
        commissionAmount,
        deliveryFee,
        totalAmount,
        status: 'pending',
      });

      prescription.status = 'quoted';
      await prescription.save();
    }

    // Notify patient
    try {
      await sendNotificationToUser(
        prescription.patientId.toString(),
        isEdit ? 'Quote Updated' : 'Quote Received',
        `${isEdit ? 'Updated quote' : 'New quote'} of ${totalAmount} MAD from ${pharmacy.pharmacyName}`,
        { quoteId: quote._id.toString(), type: 'quote_received' }
      );
    } catch (_) {}

    return successResponse(
      {
        quote: {
          id: quote._id,
          items: quote.items,
          subtotal: quote.subtotal,
          commissionRate: quote.commissionRate,
          commissionAmount: quote.commissionAmount,
          deliveryFee: quote.deliveryFee,
          totalAmount: quote.totalAmount,
        },
        isEdit,
      },
      isEdit ? 'Quote updated successfully' : 'Quote sent successfully',
      201
    );
  } catch (error: any) {
    console.error('Send quote error:', error);
    return errorResponse('Failed to send quote', 500);
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
