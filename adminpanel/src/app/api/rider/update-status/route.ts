import { NextRequest } from 'next/server';
import connectDB from '@/lib/mongodb';
import Order from '@/models/Order';
import Rider from '@/models/Rider';
import { incRiderEarnings } from '@/lib/riderWallet';
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
      await rider.save();
      await incRiderEarnings(rider._id, order.deliveryFee || 0);
    }
    await order.save();

    // Notify patient
    try {
      const keys: Record<string, string> = {
        picked_up: 'order_picked_up',
        in_transit: 'order_in_transit',
        delivered: 'order_delivered',
      };
      const key = keys[status];
      if (key) {
        await sendNotificationToPatient(order.patientId.toString(), key, undefined, {
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
