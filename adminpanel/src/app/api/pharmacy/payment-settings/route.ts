import { NextRequest } from 'next/server';
import connectDB from '@/lib/mongodb';
import Pharmacy from '@/models/Pharmacy';
import { authenticateRequest } from '@/lib/auth';
import { successResponse, errorResponse, unauthorizedResponse } from '@/lib/response';

export const dynamic = 'force-dynamic';

export async function GET(request: NextRequest) {
  try {
    const auth = await authenticateRequest(request);
    if (!auth || auth.role !== 'pharmacy') return unauthorizedResponse();

    await connectDB();

    const pharmacy = await Pharmacy.findOne({ userId: auth.userId });
    if (!pharmacy) return errorResponse('Pharmacy not found', 404);

    return successResponse(pharmacy.paymentSettings || []);
  } catch (error: any) {
    return errorResponse('Failed to fetch payment settings', 500);
  }
}

export async function PUT(request: NextRequest) {
  try {
    const auth = await authenticateRequest(request);
    if (!auth || auth.role !== 'pharmacy') return unauthorizedResponse();

    await connectDB();

    const body = await request.json();
    const { paymentSettings } = body;

    if (!Array.isArray(paymentSettings)) {
      return errorResponse('Invalid payment settings format', 400);
    }

    const pharmacy = await Pharmacy.findOneAndUpdate(
      { userId: auth.userId },
      { $set: { paymentSettings } },
      { new: true }
    );

    if (!pharmacy) return errorResponse('Pharmacy not found', 404);

    return successResponse(pharmacy.paymentSettings, 'Payment settings updated successfully');
  } catch (error: any) {
    return errorResponse('Failed to update payment settings', 500);
  }
}
