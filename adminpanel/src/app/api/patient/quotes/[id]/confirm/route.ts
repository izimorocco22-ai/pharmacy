import { NextRequest } from 'next/server';
import { connectDB } from '@/lib/mongodb';
import Quote from '@/models/Quote';
import Order from '@/models/Order';
import Prescription from '@/models/Prescription';
import Pharmacy from '@/models/Pharmacy';
import Rider from '@/models/Rider';
import { authenticateRequest } from '@/lib/auth';
import { successResponse, errorResponse, unauthorizedResponse } from '@/lib/response';
import { sendNotificationToUser } from '@/services/notification';
import { findRidersToNotify } from '@/services/rider-dispatch';

export const dynamic = 'force-dynamic';

export async function POST(request: NextRequest, { params }: { params: { id: string } }) {
  try {
    const auth = await authenticateRequest(request);
    if (!auth || auth.role !== 'patient') return unauthorizedResponse();

    await connectDB();

    const { paymentMethod = 'cash' } = await request.json().catch(() => ({}));

    const quote = await Quote.findById(params.id);
    if (!quote) return errorResponse('Quote not found', 404);
    
    if (quote.status !== 'pending' || (quote.expiresAt && new Date() > new Date(quote.expiresAt))) {
      if (quote.status === 'pending') {
        quote.status = 'expired';
        await quote.save();
      }
      return errorResponse('Quote has expired and is no longer available');
    }

    // Cash on delivery skips the payment-proof requirement.
    const isCod = paymentMethod === 'cash';
    if (!isCod && !quote.paymentProofUrl) {
      return errorResponse('Payment proof is required before confirming the order', 400);
    }

    const prescription = await Prescription.findById(quote.prescriptionId);
    if (!prescription) return errorResponse('Prescription not found', 404);

    const pharmacy = await Pharmacy.findById(quote.pharmacyId);
    if (!pharmacy) return errorResponse('Pharmacy not found', 404);

    const orderNumber = `ORD-${Date.now()}-${Math.floor(Math.random() * 1000)}`;

    const order = await Order.create({
      orderNumber,
      prescriptionId: quote.prescriptionId,
      quoteId: quote._id,
      patientId: quote.patientId,
      pharmacyId: quote.pharmacyId,
      items: quote.items,
      subtotal: quote.subtotal,
      commissionRate: quote.commissionRate,
      commissionAmount: quote.commissionAmount,
      deliveryFee: quote.deliveryFee,
      totalAmount: quote.totalAmount,
      paymentMethod,
      paymentMethodDetails: quote.paymentMethod,
      paymentProofUrl: quote.paymentProofUrl || null,
      paymentStatus: 'pending',
      // COD is confirmed straight away; paid orders wait for the pharmacy to
      // verify the uploaded proof.
      status: isCod ? 'confirmed' : 'payment_verification',
      deliveryAddress: prescription.deliveryAddress,
      pharmacyAddress: { address: pharmacy.address, location: pharmacy.location },
      estimatedDeliveryTime: new Date(Date.now() + 60 * 60 * 1000),
    });

    quote.status = 'accepted';
    await quote.save();

    prescription.status = 'accepted';
    await prescription.save();

    if (isCod) {
      // Notify the pharmacy to prepare the order, and alert nearby riders.
      try {
        await sendNotificationToUser(
          pharmacy.userId.toString(),
          'order_confirmed_pharmacy_cod',
          { orderNumber },
          { orderId: order._id.toString(), type: 'order_confirmed' }
        );
      } catch (_) {}

      try {
        const nearbyRiders = await findRidersToNotify(pharmacy.location);
        for (const rider of nearbyRiders) {
          await sendNotificationToUser(
            rider.userId.toString(),
            'delivery_available',
            { fee: order.deliveryFee },
            { orderId: order._id.toString(), type: 'delivery_available' }
          );
        }
      } catch (_) {}
    } else {
      // Paid: tell the pharmacy a proof was submitted so they can verify.
      try {
        await sendNotificationToUser(
          pharmacy.userId.toString(),
          'payment_proof_received',
          { orderNumber },
          { orderId: order._id.toString(), type: 'payment_proof_received' }
        );
      } catch (_) {}
    }

    return successResponse({
      order: {
        id: order._id,
        orderNumber: order.orderNumber,
        status: order.status,
        totalAmount: order.totalAmount,
        paymentMethod: order.paymentMethod,
      },
    }, 'Order confirmed successfully', 201);
  } catch (error) {
    console.error('Confirm quote error:', error);
    return errorResponse('Failed to confirm order', 500);
  }
}
