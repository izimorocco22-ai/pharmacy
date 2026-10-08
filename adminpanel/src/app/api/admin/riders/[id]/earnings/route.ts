import { NextRequest } from 'next/server';
import connectDB from '@/lib/mongodb';
import Rider from '@/models/Rider';
import RiderWalletTransaction from '@/models/RiderWalletTransaction';
import { incRiderEarnings } from '@/lib/riderWallet';
import { verifyToken } from '@/lib/auth';
import { successResponse, errorResponse, unauthorizedResponse } from '@/lib/response';
import { sendNotificationToUser } from '@/services/notification';

export const dynamic = 'force-dynamic';

function isAdmin(request: NextRequest) {
  const token = request.cookies.get('admin_token')?.value;
  return !!token && verifyToken(token)?.role === 'admin';
}

// GET: the rider's earnings and the admin's adjustment history
export async function GET(request: NextRequest, { params }: { params: { id: string } }) {
  if (!isAdmin(request)) return unauthorizedResponse();
  try {
    await connectDB();
    const rider = await Rider.findById(params.id).lean() as any;
    if (!rider) return errorResponse('Rider not found', 404);

    const transactions = await RiderWalletTransaction.find({ riderId: rider._id })
      .sort({ createdAt: -1 })
      .limit(100)
      .lean();

    return successResponse({ totalEarnings: rider.totalEarnings || 0, transactions });
  } catch (error) {
    console.error('Get rider earnings error:', error);
    return errorResponse('Failed to load earnings', 500);
  }
}

// POST { action: 'deduct' | 'add', amount, note }: adjust the rider's earnings
export async function POST(request: NextRequest, { params }: { params: { id: string } }) {
  if (!isAdmin(request)) return unauthorizedResponse();
  try {
    await connectDB();
    const body = await request.json();
    const action = body.action === 'add' ? 'add' : body.action === 'deduct' ? 'deduct' : null;
    if (!action) return errorResponse('Action must be "deduct" or "add"');

    const amount = Math.round(Number(body.amount) * 100) / 100;
    if (!Number.isFinite(amount) || amount <= 0) {
      return errorResponse('Amount must be greater than zero');
    }
    const note = (body.note || '').toString().trim().slice(0, 300);

    const rider = await Rider.findById(params.id).lean() as any;
    if (!rider) return errorResponse('Rider not found', 404);

    // A deduction only succeeds if the earnings cover it
    const updated = await incRiderEarnings(rider._id, action === 'deduct' ? -amount : amount);
    if (!updated) {
      return errorResponse(
        `Cannot deduct ${amount} MRO: earnings are only ${rider.totalEarnings || 0} MRO`
      );
    }

    const transaction = await RiderWalletTransaction.create({
      riderId: rider._id,
      type: action,
      amount,
      balanceAfter: updated.totalEarnings,
      note,
    });

    try {
      await sendNotificationToUser(
        rider.userId.toString(),
        action === 'deduct' ? 'Earnings Deducted' : 'Earnings Added',
        action === 'deduct'
          ? `${amount.toFixed(2)} MRO was deducted from your earnings.${note ? ` Reason: ${note}` : ''}`
          : `${amount.toFixed(2)} MRO was added to your earnings.${note ? ` Note: ${note}` : ''}`,
        { type: action === 'deduct' ? 'earnings_deduct' : 'earnings_credit', amount: String(amount) }
      );
    } catch (_) {}

    return successResponse(
      { totalEarnings: updated.totalEarnings, transaction },
      action === 'deduct' ? 'Amount deducted' : 'Amount added',
      201
    );
  } catch (error) {
    console.error('Update rider earnings error:', error);
    return errorResponse('Failed to update earnings', 500);
  }
}
