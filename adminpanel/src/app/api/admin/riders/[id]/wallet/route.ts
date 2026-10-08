import { NextRequest } from 'next/server';
import connectDB from '@/lib/mongodb';
import Rider from '@/models/Rider';
import RiderWalletTransaction from '@/models/RiderWalletTransaction';
import { verifyToken } from '@/lib/auth';
import { successResponse, errorResponse, unauthorizedResponse } from '@/lib/response';
import { sendNotificationToUser } from '@/services/notification';

export const dynamic = 'force-dynamic';

function isAdmin(request: NextRequest) {
  const token = request.cookies.get('admin_token')?.value;
  return !!token && verifyToken(token)?.role === 'admin';
}

// Legacy riders have no walletBalance yet; their unpaid balance is their
// lifetime earnings. Persist that once so atomic $inc works from here on.
async function ensureWalletBalance(riderId: string) {
  const rider = await Rider.findById(riderId).lean() as any;
  if (!rider) return null;
  if (rider.walletBalance == null) {
    await Rider.updateOne(
      { _id: rider._id, walletBalance: { $exists: false } },
      { $set: { walletBalance: rider.totalEarnings || 0 } }
    );
    rider.walletBalance = rider.totalEarnings || 0;
  }
  return rider;
}

// GET: current balance and the admin's wallet history for this rider
export async function GET(request: NextRequest, { params }: { params: { id: string } }) {
  if (!isAdmin(request)) return unauthorizedResponse();
  try {
    await connectDB();
    const rider = await ensureWalletBalance(params.id);
    if (!rider) return errorResponse('Rider not found', 404);

    const transactions = await RiderWalletTransaction.find({ riderId: rider._id })
      .sort({ createdAt: -1 })
      .limit(100)
      .lean();

    return successResponse({
      walletBalance: rider.walletBalance,
      totalEarnings: rider.totalEarnings || 0,
      transactions,
    });
  } catch (error) {
    console.error('Get rider wallet error:', error);
    return errorResponse('Failed to load wallet', 500);
  }
}

// POST { action: 'deduct' | 'add', amount, note }: change the wallet balance
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

    const rider = await ensureWalletBalance(params.id);
    if (!rider) return errorResponse('Rider not found', 404);

    // Atomic update; a deduction only succeeds if the balance covers it
    const filter: any = { _id: rider._id };
    if (action === 'deduct') filter.walletBalance = { $gte: amount };
    const updated = await Rider.findOneAndUpdate(
      filter,
      { $inc: { walletBalance: action === 'deduct' ? -amount : amount } },
      { new: true }
    ).lean() as any;

    if (!updated) {
      return errorResponse(
        `Cannot deduct ${amount} MRO: wallet balance is only ${rider.walletBalance} MRO`
      );
    }

    const transaction = await RiderWalletTransaction.create({
      riderId: rider._id,
      type: action,
      amount,
      balanceAfter: updated.walletBalance,
      note,
    });

    try {
      await sendNotificationToUser(
        rider.userId.toString(),
        action === 'deduct' ? 'Wallet Deduction' : 'Wallet Credit',
        action === 'deduct'
          ? `${amount.toFixed(2)} MRO was deducted from your wallet.${note ? ` Reason: ${note}` : ''}`
          : `${amount.toFixed(2)} MRO was added to your wallet.${note ? ` Note: ${note}` : ''}`,
        { type: action === 'deduct' ? 'wallet_deduct' : 'wallet_credit', amount: String(amount) }
      );
    } catch (_) {}

    return successResponse(
      { walletBalance: updated.walletBalance, transaction },
      action === 'deduct' ? 'Amount deducted' : 'Amount added',
      201
    );
  } catch (error) {
    console.error('Update rider wallet error:', error);
    return errorResponse('Failed to update wallet', 500);
  }
}
