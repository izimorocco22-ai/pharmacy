import { NextRequest } from 'next/server';
import { connectDB } from '@/lib/mongodb';
import Quote from '@/models/Quote';
import Patient from '@/models/Patient';
import Pharmacy from '@/models/Pharmacy';
import User from '@/models/User';
import { authenticateRequest } from '@/lib/auth';
import { successResponse, errorResponse, unauthorizedResponse } from '@/lib/response';
import { sendNotificationToUser } from '@/services/notification';
import Prescription from '@/models/Prescription';

export const dynamic = 'force-dynamic';

export async function GET(request: NextRequest) {
  try {
    const auth = await authenticateRequest(request);
    if (!auth || auth.role !== 'patient') return unauthorizedResponse();

    await connectDB();

    const patient = await Patient.findOne({ userId: auth.userId }).lean() as any;
    if (!patient) return errorResponse('Patient not found', 404);

    // Auto-expire quotes that are past their expiry time
    const now = new Date();
    const expiredQuotes = await Quote.find({
      patientId: patient._id,
      status: 'pending',
      expiresAt: { $lt: now },
    });

    if (expiredQuotes.length > 0) {
      for (const q of expiredQuotes) {
        q.status = 'expired';
        await q.save();

        // Update prescription status if needed
        const prescription = await Prescription.findById(q.prescriptionId);
        if (prescription && prescription.status === 'quoted') {
          // Check if there are other pending quotes
          const otherQuotes = await Quote.countDocuments({
            prescriptionId: q.prescriptionId,
            status: 'pending',
            _id: { $ne: q._id }
          });
          if (otherQuotes === 0) {
            prescription.status = 'expired';
            await prescription.save();
          }
        }

        // Notify pharmacy that quote expired
        try {
          const pharmacy = await Pharmacy.findById(q.pharmacyId).lean() as any;
          if (pharmacy) {
            await sendNotificationToUser(
              pharmacy.userId.toString(),
              'Quote Expired',
              'Your quote has expired as the patient did not respond within 1 hour.',
              { quoteId: q._id.toString(), type: 'quote_expired' }
            );
          }
        } catch (_) {}
      }
    }

    const quotes = await Quote.find({
      patientId: patient._id,
      status: 'pending',
    }).sort({ createdAt: -1 }).limit(20).lean() as any[];

    const formatted = await Promise.all(
      quotes.map(async (q: any) => {
        let pharmacyName = 'Unknown Pharmacy';
        let pharmacyPhone = '';
        try {
          const pharmacy = await Pharmacy.findById(q.pharmacyId).lean() as any;
          if (pharmacy) {
            pharmacyName = pharmacy.pharmacyName || 'Unknown Pharmacy';
            const pharmacyUser = await User.findById(pharmacy.userId).select('phone').lean() as any;
            pharmacyPhone = pharmacyUser?.phone || '';
          }
        } catch (_) {}

        return {
          id: q._id,
          prescriptionId: q.prescriptionId,
          pharmacyId: q.pharmacyId,
          pharmacyName,
          pharmacyPhone,
          items: q.items,
          subtotal: q.subtotal,
          commissionRate: q.commissionRate || 0,
          commissionAmount: q.commissionAmount || 0,
          deliveryFee: q.deliveryFee,
          totalAmount: q.totalAmount,
          paymentMethodDetails: q.paymentMethod || null,
          status: q.status,
          expiresAt: q.expiresAt,
          createdAt: q.createdAt,
        };
      })
    );

    return successResponse({ quotes: formatted });
  } catch (error) {
    console.error('Get patient quotes error:', error);
    return errorResponse('Failed to fetch quotes', 500);
  }
}
