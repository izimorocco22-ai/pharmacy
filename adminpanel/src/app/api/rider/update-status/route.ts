import { NextRequest } from 'next/server';
import connectDB from '@/lib/mongodb';
import Order from '@/models/Order';
import Rider from '@/models/Rider';
import { authenticateRequest } from '@/lib/auth';
import { successResponse, errorResponse, unauthorizedResponse } from '@/lib/response';
import { sendNotificationToPatient } from '@/services/notification';

export const dynamic = 'force-dynamic';

export async function PUT(request: NextRequest) {
  try {
    const auth = await authenticateRequest(request);
    if (!auth || auth.role !== 'rider') return unauthorizedResponse();

    await connectDB();

    const { orderId, status } = await request.json();
    if (!orderId || !status) return errorResponse('orderId and status are required');

    const allowed = ['picked_up', 'in_transit', 'delivered'];
    if (!allowed.includes(status)) return errorResponse('Invalid status');

    const rider = await Rider.findOne({ userId: auth.userId });
    if (!rider) return errorResponse('Rider not found', 404);

    const order = await Order.findById(orderId);
    if (!order) return errorResponse('Order not found', 404);

    if (order.riderId?.toString() !== rider._id.toString()) {
      return errorResponse('Not authorized for this order');
    }

    order.status = status;
    if (status === 'delivered') {
      order.deliveredAt = new Date();
      // Free up rider and keep them online for next delivery
      rider.isAvailable = true;
      rider.isOnline = true;
      rider.totalDeliveries = (rider.totalDeliveries || 0) + 1;
      rider.totalEarnings = (rider.totalEarnings || 0) + order.deliveryFee;
      await rider.save();
    }
    await order.save();

    // Notify patient
    try {
      const messages: Record<string, { title: string; body: string }> = {
        picked_up: { title: 'Order Picked Up', body: 'Your order has been picked up and is on the way!' },
        in_transit: { title: 'Order On The Way', body: 'Your order is on the way to you.' },
        delivered: { title: 'Order Delivered!', body: 'Your order has been delivered. Enjoy!' },
      };
      const msg = messages[status];
      if (msg) {
        await sendNotificationToPatient(order.patientId.toString(), msg.title, msg.body, {
          orderId: order._id.toString(),
          type: `order_${status}`,
        });
      }
    } catch (_) {}

    return successResponse({ status: order.status }, 'Status updated');
  } catch (error) {
    console.error('Update status error:', error);
    return errorResponse('Failed to update status', 500);
  }
}
