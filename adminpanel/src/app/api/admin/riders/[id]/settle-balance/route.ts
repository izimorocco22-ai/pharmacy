import { NextRequest } from 'next/server';
import connectDB from '@/lib/mongodb';
import Rider from '@/models/Rider';
import RiderWalletTransaction from '@/models/RiderWalletTransaction';
import { successResponse, errorResponse } from '@/lib/response';
import { sendNotificationToUser } from '@/services/notification';

export const dynamic = 'force-dynamic';

// POST: mark the rider's delivery payments as settled — resets the unpaid
// wallet balance to zero. Lifetime totalEarnings is kept for statistics.
export async function POST(
  _request: NextRequest,
  { params }: { params: { id: string } }
) {
  try {
    await connectDB();

    const rider = await Rider.findById(params.id);
    if (!rider) return errorResponse('Rider not found', 404);

    const settledAmount = rider.walletBalance ?? rider.totalEarnings ?? 0;
    rider.walletBalance = 0;
    await rider.save();

    if (settledAmount > 0) {
      await RiderWalletTransaction.create({
        riderId: rider._id,
        type: 'payout',
        amount: settledAmount,
        balanceAfter: 0,
        note: 'Balance paid out',
      });
    }

    // Notify the rider that the payout was made
    try {
      await sendNotificationToUser(
        rider.userId.toString(),
        'Payment Settled',
        `Your delivery earnings of ${settledAmount.toFixed(2)} MRO have been paid out. Wallet balance reset.`,
        { type: 'payout_settled', amount: String(settledAmount) }
      );
    } catch (_) {}

    return successResponse(
      { settledAmount },
      'Rider balance settled and reset to zero'
    );
  } catch (error) {
    console.error('Settle rider balance error:', error);
    return errorResponse('Failed to settle balance', 500);
  }
}
