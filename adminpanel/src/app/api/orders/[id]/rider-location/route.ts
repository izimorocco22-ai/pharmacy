import { NextRequest } from 'next/server';
import connectDB from '@/lib/mongodb';
import Order from '@/models/Order';
import Rider from '@/models/Rider';
import Patient from '@/models/Patient';
import { authenticateRequest } from '@/lib/auth';
import { successResponse, errorResponse, unauthorizedResponse } from '@/lib/response';

export const dynamic = 'force-dynamic';

export async function GET(request: NextRequest, { params }: { params: { id: string } }) {
  try {
    const auth = await authenticateRequest(request);
    if (!auth || auth.role !== 'patient') return unauthorizedResponse();

    await connectDB();

    const patient = await Patient.findOne({ userId: auth.userId }).lean() as any;
    if (!patient) return errorResponse('Patient not found', 404);

    const order = await Order.findOne({
      _id: params.id,
      patientId: patient._id,
    }).select('riderId status').lean() as any;

    if (!order) return errorResponse('Order not found', 404);

    if (!order.riderId) {
      return errorResponse('No rider assigned yet', 404);
    }

    const rider = await Rider.findById(order.riderId)
      .select('currentLocation isOnline')
      .lean() as any;

    if (!rider?.currentLocation?.coordinates?.length) {
      return errorResponse('Rider location not available', 404);
    }

    const [lng, lat] = rider.currentLocation.coordinates;

    return successResponse({
      lat,
      lng,
      isOnline: rider.isOnline,
      orderStatus: order.status,
    });
  } catch (error) {
    console.error('Rider location error:', error);
    return errorResponse('Failed to fetch rider location', 500);
  }
}
