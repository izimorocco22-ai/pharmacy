import { NextRequest } from 'next/server';
import connectDB from '@/lib/mongodb';
import Order from '@/models/Order';
import Quote from '@/models/Quote';
import Prescription from '@/models/Prescription';
import Pharmacy from '@/models/Pharmacy';
import Rider from '@/models/Rider';
import { authenticateRequest } from '@/lib/auth';
import { successResponse, errorResponse, unauthorizedResponse } from '@/lib/response';
import { sendNotificationToUser } from '@/services/notification';

// Build a human-friendly order name from the quoted medicine items, e.g.
// "Paracetamol" or "Paracetamol +2 more". Falls back to "Medicine Order".
function buildOrderName(items: Array<{ medicineName?: string }> = []): string {
  const names = items
    .map((i) => (i.medicineName || '').trim())
    .filter((n) => n && n.toLowerCase() !== 'total');

  if (names.length === 0) return 'Medicine Order';
  if (names.length === 1) return names[0];
  return `${names[0]} +${names.length - 1} more`;
}

export async function POST(request: NextRequest) {
  try {
    const auth = await authenticateRequest(request);
    if (!auth || auth.role !== 'patient') {
      return unauthorizedResponse();
    }

    await connectDB();

    const body = await request.json();
    const { quoteId, paymentMethod } = body;

    if (!quoteId || !paymentMethod) {
      return errorResponse('Quote ID and payment method are required');
    }

    // Get quote
    const quote = await Quote.findById(quoteId).populate('pharmacyId');
    if (!quote) {
      return errorResponse('Quote not found', 404);
    }

    if (quote.status !== 'pending') {
      return errorResponse('Quote is no longer available');
    }

    // Check if quote expired
    if (new Date() > quote.expiresAt) {
      quote.status = 'expired';
      await quote.save();
      return errorResponse('Quote has expired');
    }

    // Get prescription
    const prescription = await Prescription.findById(quote.prescriptionId);
    if (!prescription) {
      return errorResponse('Prescription not found', 404);
    }

    // Get pharmacy details
    const pharmacy = await Pharmacy.findById(quote.pharmacyId);

    // Generate order number
    const orderNumber = `ORD-${Date.now()}-${Math.floor(Math.random() * 1000)}`;

    // Generate a meaningful, medicine-based name so the patient can recognise
    // the order later (the order number/code remains the unique identifier).
    const orderName = buildOrderName(quote.items);

    // Create order
    const order = await Order.create({
      orderNumber,
      name: orderName,
      prescriptionId: quote.prescriptionId,
      quoteId: quote._id,
      patientId: quote.patientId,
      pharmacyId: quote.pharmacyId,
      items: quote.items,
      subtotal: quote.subtotal,
      deliveryFee: quote.deliveryFee,
      totalAmount: quote.totalAmount,
      paymentMethod,
      paymentStatus: paymentMethod === 'online' ? 'pending' : 'pending',
      status: 'confirmed',
      deliveryAddress: prescription.deliveryAddress,
      pharmacyAddress: {
        address: pharmacy!.address,
        location: pharmacy!.location,
      },
      estimatedDeliveryTime: new Date(Date.now() + 60 * 60 * 1000), // 1 hour
    });

    // Update quote status
    quote.status = 'accepted';
    await quote.save();

    // Update prescription status (and name it after the medicines)
    prescription.status = 'accepted';
    prescription.name = orderName;
    await prescription.save();

    // Notify pharmacy
    await sendNotificationToUser(
      pharmacy!.userId.toString(),
      'New Order Confirmed',
      `Order ${orderNumber} has been confirmed. Please prepare the medicines.`,
      {
        orderId: order._id.toString(),
        type: 'order_confirmed',
      }
    );

    // Find nearby riders
    const nearbyRiders = await Rider.find({
      currentLocation: {
        $near: {
          $geometry: pharmacy!.location,
          $maxDistance: 10000, // 10km
        },
      },
      isAvailable: true,
      isOnline: true,
    }).limit(10);

    // Notify riders
    if (nearbyRiders.length > 0) {
      for (const rider of nearbyRiders) {
        await sendNotificationToUser(
          rider.userId.toString(),
          'New Delivery Available',
          `Delivery fee: ${order.deliveryFee} MRO`,
          {
            orderId: order._id.toString(),
            type: 'delivery_available',
          }
        );
      }
    }

    return successResponse(
      {
        order: {
          id: order._id,
          orderNumber: order.orderNumber,
          status: order.status,
          totalAmount: order.totalAmount,
          paymentMethod: order.paymentMethod,
          estimatedDeliveryTime: order.estimatedDeliveryTime,
        },
      },
      'Order confirmed successfully',
      201
    );
  } catch (error: any) {
    console.error('Confirm order error:', error);
    return errorResponse('Failed to confirm order', 500);
  }
}
