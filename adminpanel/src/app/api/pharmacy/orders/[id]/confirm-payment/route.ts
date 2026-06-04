import { NextRequest } from 'next/server';
import connectDB from '@/lib/mongodb';
import Order from '@/models/Order';
import Pharmacy from '@/models/Pharmacy';
import { authenticateRequest } from '@/lib/auth';
import { successResponse, errorResponse, unauthorizedResponse } from '@/lib/response';
import { sendNotificationToUser } from '@/services/notification';

export async function POST(request: NextRequest, { params }: { params: { id: string } }) {
  try {
    const auth = await authenticateRequest(request);
    if (!auth || auth.role !== 'pharmacy') return unauthorizedResponse();

    await connectDB();

    const pharmacy = await Pharmacy.findOne({ userId: auth.userId });
    if (!pharmacy) return errorResponse('Pharmacy not found', 404);

    const order = await Order.findOne({ _id: params.id, pharmacyId: pharmacy._id });
    if (!order) return errorResponse('Order not found', 404);

    if (!order.paymentProofUrl) {
      return errorResponse('No payment proof found for this order', 400);
    }

    if (order.paymentStatus === 'paid') {
      return errorResponse('Payment already confirmed', 400);
    }

    order.paymentStatus = 'paid';
    order.status = 'confirmed';
    await order.save();

    // Notify patient
    try {
      await sendNotificationToUser(
        order.patientId.toString(),
        'Payment Confirmed! 🎉',
        `Your payment for order ${order.orderNumber} has been verified. Your order is now confirmed!`,
        { orderId: order._id.toString(), type: 'payment_confirmed' }
      );
    } catch (_) {}

    return successResponse({
      orderId: order._id,
      status: order.status,
      paymentStatus: order.paymentStatus,
    }, 'Payment confirmed. Order is now confirmed.');
  } catch (error) {
    console.error('Confirm payment error:', error);
    return errorResponse('Failed to confirm payment', 500);
  }
}
