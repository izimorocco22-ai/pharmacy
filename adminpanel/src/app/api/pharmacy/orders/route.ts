import { NextRequest } from 'next/server';
import connectDB from '@/lib/mongodb';
import Order from '@/models/Order';
import Pharmacy from '@/models/Pharmacy';
import Prescription from '@/models/Prescription';
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

    const orders = await Order.find({ pharmacyId: pharmacy._id })
      .sort({ createdAt: -1 })
      .limit(50)
      .populate({ path: 'prescriptionId', model: Prescription, select: 'imageUrl medicines' })
      .lean();

    const formatted = orders.map((o: any) => ({
      id: o._id,
      orderNumber: o.orderNumber,
      status: o.status,
      subtotal: o.subtotal,
      deliveryFee: o.deliveryFee,
      totalAmount: o.totalAmount,
      paymentMethod: o.paymentMethod,
      paymentMethodDetails: o.paymentMethodDetails || null,
      paymentProofUrl: o.paymentProofUrl || null,
      paymentStatus: o.paymentStatus,
      items: o.items,
      createdAt: o.createdAt,
      prescriptionImage: o.prescriptionId?.imageUrl || '',
      medicines: o.prescriptionId?.medicines || [],
    }));

    return successResponse({ orders: formatted });
  } catch (error: any) {
    console.error('Pharmacy orders error:', error);
    return errorResponse('Failed to fetch orders', 500);
  }
}
