import { NextRequest } from 'next/server';
import connectDB from '@/lib/mongodb';
import Order from '@/models/Order';
import Pharmacy from '@/models/Pharmacy';
import Prescription from '@/models/Prescription';
import Quote from '@/models/Quote';
import { authenticateRequest } from '@/lib/auth';
import { successResponse, errorResponse, unauthorizedResponse } from '@/lib/response';
import User from '@/models/User';
import { translateStatusText, normalizeLang } from '@/services/notification-i18n';
import { translateFreeTextBatch } from '@/services/translate';

export const dynamic = 'force-dynamic';

export async function GET(request: NextRequest) {
  try {
    const auth = await authenticateRequest(request);
    if (!auth || auth.role !== 'pharmacy') return unauthorizedResponse();

    // These rows carry backend-authored status text, so it has to be rendered
    // in the viewing pharmacy's language rather than always in English.
    const viewer = await User.findById(auth.userId).select('language').lean() as any;
    const lang = normalizeLang(viewer?.language);

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

    // Translate every distinct typed reason up front: the map below is
    // synchronous, and doing it here means one call per distinct sentence
    // rather than one per row.
    const freeText = await translateFreeTextBatch(
      closedQuotes.map((q: any) => q.rejectionReason),
      lang
    );

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
        // A reason the pharmacist typed is free text in their own words, so it
        // is machine-translated for the viewer (no-op unless TRANSLATE_PROVIDER
        // is configured). Our own fallback sentences use the hand-written
        // catalogue instead.
        const reason = q.status === 'expired'
          ? translateStatusText('quote_not_accepted_in_time', lang)
          : q.rejectionReason
            ? freeText.get(q.rejectionReason) || q.rejectionReason
            : translateStatusText('patient_cancelled_quote', lang);
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
