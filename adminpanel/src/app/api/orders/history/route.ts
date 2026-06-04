import { NextRequest } from 'next/server';
import connectDB from '@/lib/mongodb';
import Order from '@/models/Order';
import Quote from '@/models/Quote';
import Prescription from '@/models/Prescription';
import Patient from '@/models/Patient';
import Pharmacy from '@/models/Pharmacy';
import User from '@/models/User';
import Rider from '@/models/Rider';
import { successResponse, errorResponse } from '@/lib/response';
import jwt from 'jsonwebtoken';

export const dynamic = 'force-dynamic';

export async function GET(request: NextRequest) {
  try {
    await connectDB();

    const authHeader = request.headers.get('authorization');
    let userId = request.nextUrl.searchParams.get('userId');

    if (authHeader?.startsWith('Bearer ')) {
      try {
        const token = authHeader.substring(7);
        const decoded = jwt.verify(token, process.env.JWT_SECRET || 'your-secret-key') as any;
        userId = decoded.userId || decoded.id;
      } catch (_) {}
    }

    if (!userId) return successResponse([], 'No orders found');

    const patient = await Patient.findOne({ userId }).lean() as any;
    if (!patient) return successResponse([], 'No orders found');

    // Fetch confirmed orders
    const orders = await Order.find({ patientId: patient._id })
      .sort({ createdAt: -1 })
      .populate('pharmacyId', 'pharmacyName address phone')
      .populate({ path: 'riderId', model: Rider, select: 'userId vehicleType' })
      .populate('quoteId')
      .populate({ path: 'prescriptionId', select: 'imageUrl deliveryAddress medicines' })
      .lean() as any[];

    // Fetch pending prescriptions (order created, searching for pharmacy)
    const pendingPrescriptions = await Prescription.find({
      patientId: patient._id,
      status: 'pending',
    }).sort({ createdAt: -1 }).lean() as any[];

    const enrichedPrescriptions = await Promise.all(pendingPrescriptions.map(async (p: any) => {
      // Get full quote history for this prescription to show rejections
      let quoteHistory: any[] = [];
      try {
        const quotes = await Quote.find({ prescriptionId: p._id })
          .sort({ createdAt: 1 })
          .lean() as any[];

        quoteHistory = await Promise.all(quotes.map(async (q: any) => {
          let pharmacyName = 'Unknown Pharmacy';
          try {
            const ph = await Pharmacy.findById(q.pharmacyId).lean() as any;
            if (ph) pharmacyName = ph.pharmacyName || 'Unknown';
          } catch (_) {}

          return {
            id: q._id?.toString(),
            pharmacyName,
            status: q.status,
            rejectionReason: q.rejectionReason || '',
            createdAt: q.createdAt,
          };
        }));
      } catch (_) {}

      return {
        _isPendingQuote: false,
        id: p._id?.toString(),
        prescriptionId: p._id?.toString(),
        prescriptionImage: p.imageUrl || null,
        medicines: p.medicines || [],
        pharmacyName: null,
        items: [],
        subtotal: 0,
        deliveryFee: 0,
        totalAmount: 0,
        status: 'searching',
        orderNumber: `REQ-${p._id.toString().slice(-6).toUpperCase()}`,
        createdAt: p.createdAt,
        deliveryAddress: p.deliveryAddress || null,
        quoteHistory,
      };
    }));

    // Fetch pending quotes (pharmacy sent quote but patient hasn't confirmed yet)
    const pendingQuotes = await Quote.find({
      patientId: patient._id,
      status: 'pending',
    }).sort({ createdAt: -1 }).lean() as any[];

    // Enrich pending quotes with pharmacy info
    const enrichedQuotes = await Promise.all(
      pendingQuotes.map(async (q: any) => {
        let pharmacyName = 'Unknown Pharmacy';
        let pharmacyPhone = '';
        let pharmacyAddress = '';
        try {
          const pharmacy = await Pharmacy.findById(q.pharmacyId).lean() as any;
          if (pharmacy) {
            pharmacyName = pharmacy.pharmacyName || 'Unknown Pharmacy';
            pharmacyAddress = pharmacy.address || '';
            const pUser = await User.findById(pharmacy.userId).select('phone').lean() as any;
            pharmacyPhone = pUser?.phone || '';
          }
        } catch (_) {}

        // Get prescription image and medicines
        let prescriptionImage = null;
        let medicines: any[] = [];
        try {
          const presc = await Prescription.findById(q.prescriptionId).select('imageUrl medicines').lean() as any;
          prescriptionImage = presc?.imageUrl || null;
          medicines = presc?.medicines || [];
        } catch (_) {}

        return {
          _isPendingQuote: true,
          id: q._id?.toString(),
          quoteId: q._id?.toString(),
          prescriptionId: q.prescriptionId?.toString(),
          prescriptionImage,
          medicines,
          pharmacyName,
          pharmacyPhone,
          pharmacyAddress,
          items: q.items || [],
          subtotal: q.subtotal || 0,
          commissionRate: q.commissionRate || 0,
          commissionAmount: q.commissionAmount || 0,
          deliveryFee: q.deliveryFee || 0,
          totalAmount: q.totalAmount || 0,
          status: 'quote_pending',
          orderNumber: 'Pending Quote',
          createdAt: q.createdAt,
          expiresAt: q.expiresAt,
        };
      })
    );

    // Normalize confirmed orders
    const normalizedOrders = orders.map((o: any) => ({
      ...o,
      _isPendingQuote: false,
      id: o._id?.toString(),
      orderNumber: o.orderNumber || '',
      pharmacyName: o.pharmacyId?.pharmacyName || null,
      pharmacyPhone: o.pharmacyId?.phone || null,
      pharmacyAddress: o.pharmacyId?.address || null,
      prescriptionImage: o.prescriptionId?.imageUrl || null,
      medicines: o.prescriptionId?.medicines || [],
      totalAmount: o.totalAmount || 0,
      status: o.status || 'pending',
      quoteItems: o.quoteId?.items || o.items || [],
      subtotal: o.quoteId?.subtotal || o.subtotal || 0,
      commissionRate: o.quoteId?.commissionRate || o.commissionRate || 0,
      commissionAmount: o.quoteId?.commissionAmount || o.commissionAmount || 0,
      deliveryFee: o.quoteId?.deliveryFee || o.deliveryFee || 0,
    }));

    // Merge: searching prescriptions + pending quotes + confirmed orders
    const combined = [...enrichedPrescriptions, ...enrichedQuotes, ...normalizedOrders];

    return successResponse(combined, 'Orders fetched successfully');
  } catch (error: any) {
    console.error('Fetch orders error:', error);
    return errorResponse('Failed to fetch orders', 500);
  }
}
