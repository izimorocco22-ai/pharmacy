import { NextRequest } from 'next/server';
import { connectDB } from '@/lib/mongodb';
import User from '@/models/User';
import Pharmacy from '@/models/Pharmacy';
import PharmacySettlement from '@/models/PharmacySettlement';
import { successResponse, errorResponse } from '@/lib/response';

export const dynamic = 'force-dynamic';

// Resolve the pharmacy from the route id (which is the owning User._id).
async function resolvePharmacy(id: string) {
  const user = await User.findById(id).lean() as any;
  if (!user) return null;
  return (await Pharmacy.findOne({ userId: user._id }).lean()) as any;
}

// Record a payment/adjustment against the pharmacy's commission dues.
export async function POST(request: NextRequest, { params }: { params: { id: string } }) {
  try {
    await connectDB();
    const pharmacy = await resolvePharmacy(params.id);
    if (!pharmacy) return errorResponse('Pharmacy not found', 404);

    const body = await request.json();
    const amount = Number(body.amount);
    if (!Number.isFinite(amount) || amount === 0) {
      return errorResponse('A non-zero amount is required');
    }

    const settlement = await PharmacySettlement.create({
      pharmacyId: pharmacy._id,
      amount: Math.round(amount * 100) / 100,
      type: body.type === 'adjustment' ? 'adjustment' : 'payment',
      note: (body.note || '').toString().slice(0, 300),
      month: (body.month || '').toString(),
    });

    return successResponse(
      {
        settlement: {
          id: settlement._id,
          amount: settlement.amount,
          type: settlement.type,
          note: settlement.note,
          month: settlement.month,
          createdAt: settlement.createdAt,
        },
      },
      'Settlement recorded',
      201,
    );
  } catch (error) {
    console.error('Record settlement error:', error);
    return errorResponse('Failed to record settlement', 500);
  }
}
