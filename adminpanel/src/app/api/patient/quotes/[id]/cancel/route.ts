import { NextRequest } from 'next/server';
import { connectDB } from '@/lib/mongodb';
import Quote from '@/models/Quote';
import Prescription from '@/models/Prescription';
import Pharmacy from '@/models/Pharmacy';
import { authenticateRequest } from '@/lib/auth';
import { successResponse, errorResponse, unauthorizedResponse } from '@/lib/response';

export async function POST(request: NextRequest, { params }: { params: { id: string } }) {
  try {
    const auth = await authenticateRequest(request);
    if (!auth || auth.role !== 'patient') return unauthorizedResponse();

    await connectDB();

    const quote = await Quote.findById(params.id);
    if (!quote) return errorResponse('Quote not found', 404);
    if (quote.status !== 'pending') return errorResponse('Quote already processed');

    // Mark quote as rejected
    quote.status = 'rejected';
    await quote.save();

    const prescription = await Prescription.findById(quote.prescriptionId);
    if (!prescription) return errorResponse('Prescription not found', 404);

    // Cancel the prescription and don't reassign
    prescription.nearbyPharmacies = [];
    prescription.status = 'expired';
    await prescription.save();

    return successResponse({
      reassigned: false,
      message: 'Quote cancelled. Request stopped.',
    });
  } catch (error) {
    console.error('Cancel quote error:', error);
    return errorResponse('Failed to cancel quote', 500);
  }
}
