import { NextRequest } from 'next/server';
import connectDB from '@/lib/mongodb';
import Order from '@/models/Order';
import Prescription from '@/models/Prescription';
import Quote from '@/models/Quote';
import { authenticateRequest } from '@/lib/auth';
import { successResponse, errorResponse, unauthorizedResponse } from '@/lib/response';
import { sendNotificationToPharmacy, sendNotificationToRider } from '@/services/notification';

export const dynamic = 'force-dynamic';

export async function POST(
  request: NextRequest,
  { params }: { params: { id: string } }
) {
  try {
    const auth = await authenticateRequest(request);
    if (!auth || auth.role !== 'patient') return unauthorizedResponse();

    await connectDB();

    const { id } = params;

    // 1. Try to find as an Order
    let order = await Order.findById(id);

    if (order) {
      // Check if order can be cancelled (e.g., not already delivered or in transit)
      const nonCancellableStatuses = ['in_transit', 'delivered', 'picked_up'];
      if (nonCancellableStatuses.includes(order.status)) {
        return errorResponse(`Order cannot be cancelled in ${order.status} state`, 400);
      }

      order.status = 'cancelled';
      order.cancelledAt = new Date();
      order.cancellationReason = 'User cancelled the order';
      await order.save();

      // Also mark the related prescription as expired if it exists
      if (order.prescriptionId) {
        await Prescription.findByIdAndUpdate(order.prescriptionId, {
          status: 'expired',
          nearbyPharmacies: []
        });
      }

      // Notify the pharmacy (and rider if one was assigned) that the patient
      // cancelled the order.
      try {
        if (order.pharmacyId) {
          await sendNotificationToPharmacy(
            order.pharmacyId.toString(),
            'Order Cancelled',
            `Order ${order.orderNumber} was cancelled by the patient.`,
            { orderId: order._id.toString(), type: 'order_cancelled' }
          );
        }
        if (order.riderId) {
          await sendNotificationToRider(
            order.riderId.toString(),
            'Delivery Cancelled',
            `Order ${order.orderNumber} was cancelled by the patient.`,
            { orderId: order._id.toString(), type: 'order_cancelled' }
          );
        }
      } catch (_) {}

      return successResponse({ message: 'Order cancelled successfully' });
    }

    // 2. Try to find as a Prescription (searching state)
    let prescription = await Prescription.findById(id);

    if (prescription) {
      if (prescription.status === 'expired') {
        return errorResponse('Prescription is already expired/cancelled', 400);
      }

      prescription.status = 'expired';
      prescription.nearbyPharmacies = [];
      await prescription.save();

      // Also mark any pending quotes as rejected
      await Quote.updateMany(
        { prescriptionId: prescription._id, status: 'pending' },
        { status: 'rejected' }
      );

      return successResponse({ message: 'Request cancelled successfully' });
    }

    return errorResponse('Order or request not found', 404);
  } catch (error: any) {
    console.error('Cancel order error:', error?.message || error);
    return errorResponse('Failed to cancel order', 500);
  }
}
