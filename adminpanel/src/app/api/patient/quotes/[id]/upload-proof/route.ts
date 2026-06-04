import { NextRequest } from 'next/server';
import connectDB from '@/lib/mongodb';
import Quote from '@/models/Quote';
import { authenticateRequest } from '@/lib/auth';
import { successResponse, errorResponse, unauthorizedResponse } from '@/lib/response';

export async function POST(request: NextRequest, { params }: { params: { id: string } }) {
  try {
    const auth = await authenticateRequest(request);
    if (!auth || auth.role !== 'patient') return unauthorizedResponse();

    await connectDB();

    const { paymentProofUrl } = await request.json();
    if (!paymentProofUrl) return errorResponse('Payment proof image is required');

    const quote = await Quote.findById(params.id);
    if (!quote) return errorResponse('Quote not found', 404);

    if (quote.status !== 'pending') return errorResponse('Quote is no longer available');

    quote.paymentProofUrl = paymentProofUrl;
    await quote.save();

    return successResponse({ paymentProofUrl }, 'Payment proof uploaded successfully');
  } catch (error) {
    console.error('Upload proof error:', error);
    return errorResponse('Failed to upload payment proof', 500);
  }
}
