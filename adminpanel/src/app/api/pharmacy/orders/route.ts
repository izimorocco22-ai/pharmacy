import { NextRequest } from 'next/server';
import connectDB from '@/lib/mongodb';
import Order from '@/models/Order';
import Pharmacy from '@/models/Pharmacy';
import Prescription from '@/models/Prescription';
import Quote from '@/models/Quote';
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

    // Requests this pharmacy didn't turn into an order: it rejected them, or
    // the patient cancelled or let its quote expire. Requests that moved on
    // because the pharmacy ran out of time are not shown. Latest quote per
    // request only.
    const closedQuotes = await Quote.find({
      pharmacyId: pharmacy._id,
      status: { $in: ['rejected', 'expired'] },
      rejectionReason: { $not: /^Auto-reassigned/ },
    })
      .sort({ createdAt: -1 })
      .limit(50)
      .populate({ path: 'prescriptionId', model: Prescription, select: 'imageUrl medicines' })
      .lean() as any[];

    const seen = new Set<string>();
    const closed = closedQuotes
      .filter((q: any) => {
        const key = (q.prescriptionId?._id || q.prescriptionId)?.toString();
        if (!key || seen.has(key)) return false;
        seen.add(key);
        return true;
      })
      .map((q: any) => {
        const prescriptionId = (q.prescriptionId?._id || q.prescriptionId).toString();
        // A rejection reason means the pharmacy rejected (or timed out);
        // a rejected quote without one was cancelled by the patient
        const status = q.status === 'expired' ? 'expired' : q.rejectionReason ? 'rejected' : 'cancelled';
        const reason = q.status === 'expired'
          ? 'Patient did not accept the quote in time'
          : q.rejectionReason || 'Patient cancelled the quote';
        return {
          id: q._id,
          isClosedRequest: true,
          orderNumber: `REQ-${prescriptionId.slice(-6).toUpperCase()}`,
          status,
          rejectionReason: reason,
          subtotal: q.subtotal || 0,
          deliveryFee: q.deliveryFee || 0,
          totalAmount: q.totalAmount || 0,
          items: q.items || [],
          createdAt: q.updatedAt || q.createdAt,
          prescriptionImage: q.prescriptionId?.imageUrl || '',
          medicines: q.prescriptionId?.medicines || [],
        };
      });

    const all = [...formatted, ...closed]
      .sort((a: any, b: any) => new Date(b.createdAt).getTime() - new Date(a.createdAt).getTime())
      .slice(0, 50);

    return successResponse({ orders: all });
  } catch (error: any) {
    console.error('Pharmacy orders error:', error);
    return errorResponse('Failed to fetch orders', 500);
  }
}
