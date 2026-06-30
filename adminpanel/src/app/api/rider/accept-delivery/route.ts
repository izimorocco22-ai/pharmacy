import { NextRequest } from 'next/server';
import connectDB from '@/lib/mongodb';
import Order from '@/models/Order';
import Rider from '@/models/Rider';
import Pharmacy from '@/models/Pharmacy';
import Patient from '@/models/Patient';
import User from '@/models/User';
import { authenticateRequest } from '@/lib/auth';
import { successResponse, errorResponse, unauthorizedResponse } from '@/lib/response';
import { sendNotificationToPatient, sendNotificationToPharmacy } from '@/services/notification';

export const dynamic = 'force-dynamic';
export async function POST(request: NextRequest) {
  try {
    const auth = await authenticateRequest(request);
    if (!auth || auth.role !== 'rider') {
      return unauthorizedResponse();
    }

    await connectDB();

    const body = await request.json();
    const { orderId } = body;

    if (!orderId) {
      return errorResponse('Order ID is required');
    }

    // Get rider
    const rider = await Rider.findOne({ userId: auth.userId });
    if (!rider) {
      return errorResponse('Rider profile not found', 404);
    }

    if (!rider.isAvailable) {
      // Reset availability in case it got stuck
      rider.isAvailable = true;
      await rider.save();
    }

    // Get order
    const order = await Order.findById(orderId);
    if (!order) {
      return errorResponse('Order not found', 404);
    }

    if (order.riderId) {
      return errorResponse('Order already assigned to another rider');
    }

    if (!['confirmed', 'ready'].includes(order.status)) {
      return errorResponse('Order is not available for pickup');
    }

    // Assign rider to order
    order.riderId = rider._id;
    order.status = 'assigned';
    await order.save();

    // Update rider availability
    rider.isAvailable = false;
    await rider.save();

    // Notify patient
    try {
      await sendNotificationToPatient(
        order.patientId.toString(),
        'Rider Assigned',
        'A rider has been assigned to your order and will pick it up soon.',
        { orderId: order._id.toString(), type: 'rider_assigned' }
      );
    } catch (_) {}

    // Notify pharmacy
    try {
      if (order.pharmacyId) {
        await sendNotificationToPharmacy(
          order.pharmacyId.toString(),
          'Rider on the Way',
          `Rider is coming to pick up order ${order.orderNumber}`,
          { orderId: order._id.toString(), type: 'rider_coming' }
        );
      }
    } catch (_) {}

    // Fetch pharmacy phone and patient phone
    let pharmacyPhone = '';
    let patientPhone = '';
    let pharmacyName = '';
    try {
      const pharmacy = await Pharmacy.findById(order.pharmacyId).lean() as any;
      if (pharmacy) {
        pharmacyName = pharmacy.pharmacyName || '';
        const pharmUser = await User.findById(pharmacy.userId).select('phone').lean() as any;
        pharmacyPhone = pharmUser?.phone || '';
      }
    } catch (_) {}
    try {
      const patient = await Patient.findById(order.patientId).lean() as any;
      if (patient) {
        const patUser = await User.findById(patient.userId).select('phone').lean() as any;
        patientPhone = patUser?.phone || '';
      }
    } catch (_) {}

    return successResponse({
      order: {
        orderNumber: order.orderNumber,
        pickupAddress: order.pharmacyAddress?.address || '',
        deliveryAddress: order.deliveryAddress?.address || '',
        pharmacyCoords: order.pharmacyAddress?.location?.coordinates || null,
        deliveryCoords: order.deliveryAddress?.location?.coordinates || null,
        pharmacyPhone,
        pharmacyName,
        patientPhone,
      },
    });
  } catch (error: any) {
    console.error('Accept delivery error:', error);
    return errorResponse('Failed to accept delivery', 500);
  }
}
