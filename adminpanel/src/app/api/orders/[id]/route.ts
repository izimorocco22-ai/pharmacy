import { NextRequest } from 'next/server';
import connectDB from '@/lib/mongodb';
import Order from '@/models/Order';
import Quote from '@/models/Quote';
import Pharmacy from '@/models/Pharmacy';
import Rider from '@/models/Rider';
import User from '@/models/User';
import Patient from '@/models/Patient';
import Prescription from '@/models/Prescription';
import { authenticateRequest } from '@/lib/auth';
import { successResponse, errorResponse, unauthorizedResponse } from '@/lib/response';

export const dynamic = 'force-dynamic';

export async function GET(
  request: NextRequest,
  { params }: { params: { id: string } }
) {
  try {
    // Accept both Bearer token (mobile apps) and admin cookie
    const auth = await authenticateRequest(request);
    const adminToken = request.cookies.get('admin_token')?.value;
    if (!auth && !adminToken) return unauthorizedResponse();

    await connectDB();

    const order = await Order.findById(params.id)
      .populate('pharmacyId', 'pharmacyName address')
      .populate({ path: 'riderId', model: Rider })
      .populate({ path: 'prescriptionId', model: Prescription })
      .lean() as any;

    if (!order) return errorResponse('Order not found', 404);

    // Get patient info
    let patientInfo: any = null;
    try {
      const patient = await Patient.findById(order.patientId).lean() as any;
      if (patient) {
        const user = await User.findById(patient.userId).select('fullName email phone profileImage').lean() as any;
        patientInfo = { fullName: user?.fullName, email: user?.email, phone: user?.phone, profileImage: user?.profileImage };
      }
    } catch (_) {}

    // Get rider info with user details
    let riderInfo: any = null;
    if (order.riderId) {
      try {
        const riderUser = await User.findById(order.riderId.userId).select('fullName phone').lean() as any;
        riderInfo = {
          name: riderUser?.fullName || '',
          phone: riderUser?.phone || '',
          vehicleType: order.riderId.vehicleType || '',
          vehicleNumber: order.riderId.vehicleNumber || '',
          rating: order.riderId.rating || 5,
          totalDeliveries: order.riderId.totalDeliveries || 0,
        };
      } catch (_) {}
    }

    // Get full quote history for this prescription
    let quoteHistory: any[] = [];
    if (order.prescriptionId) {
      try {
        const quotes = await Quote.find({ prescriptionId: order.prescriptionId._id || order.prescriptionId })
          .sort({ createdAt: 1 })
          .lean() as any[];

        quoteHistory = await Promise.all(quotes.map(async (q: any) => {
          let pharmacyName = 'Unknown Pharmacy';
          let pharmacyAddress = '';
          try {
            const ph = await Pharmacy.findById(q.pharmacyId).lean() as any;
            if (ph) {
              pharmacyName = ph.pharmacyName || 'Unknown';
              pharmacyAddress = ph.address || '';
            }
          } catch (_) {}

          return {
            id: q._id?.toString(),
            pharmacyName,
            pharmacyAddress,
            status: q.status,
            rejectionReason: q.rejectionReason || '',
            subtotal: q.subtotal || 0,
            deliveryFee: q.deliveryFee || 0,
            totalAmount: q.totalAmount || 0,
            items: q.items || [],
            createdAt: q.createdAt,
          };
        }));
      } catch (_) {}
    }

    const prescription = order.prescriptionId as any;

    const result = {
      id: order._id?.toString(),
      orderNumber: order.orderNumber || '',
      status: order.status,
      paymentMethod: order.paymentMethod,
      paymentStatus: order.paymentStatus,
      subtotal: order.subtotal || 0,
      commissionAmount: order.commissionAmount || 0,
      deliveryFee: order.deliveryFee || 0,
      totalAmount: order.totalAmount || 0,
      createdAt: order.createdAt,
      deliveredAt: order.deliveredAt,
      estimatedDeliveryTime: order.estimatedDeliveryTime,
      // Patient
      patient: patientInfo,
      // Pharmacy
      pharmacy: order.pharmacyId ? {
        name: (order.pharmacyId as any).pharmacyName || '',
        address: (order.pharmacyId as any).address || '',
      } : null,
      // Rider
      rider: riderInfo,
      // Addresses
      deliveryAddress: order.deliveryAddress?.address || prescription?.deliveryAddress?.address || '',
      pharmacyAddress: order.pharmacyAddress?.address || '',
      // Prescription — also exposed at top level for Flutter app
      prescriptionImage: prescription?.imageUrl || '',
      medicines: prescription?.medicines || [],
      prescription: prescription ? {
        imageUrl: prescription.imageUrl || '',
        medicines: prescription.medicines || [],
      } : null,
      // Items from confirmed quote
      items: order.items || [],
      // Full quote history
      quoteHistory,
    };

    return successResponse({ order: result });
  } catch (error: any) {
    console.error('Get order error:', error?.message || error);
    return errorResponse('Failed to fetch order', 500);
  }
}
