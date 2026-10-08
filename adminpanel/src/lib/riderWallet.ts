import mongoose from 'mongoose';
import Rider from '@/models/Rider';

// A rider has one money figure: totalEarnings. Deliveries add to it and the
// admin can add or deduct. All writes go through here as atomic updates,
// never rider.save(), so a stale document can't overwrite the amount.

// Add (positive) or remove (negative) earnings. A removal only succeeds if
// the earnings cover it; returns null otherwise.
export async function incRiderEarnings(riderId: string | mongoose.Types.ObjectId, amount: number) {
  const filter: any = { _id: riderId };
  if (amount < 0) filter.totalEarnings = { $gte: -amount };
  return Rider.findOneAndUpdate(filter, { $inc: { totalEarnings: amount } }, { new: true }).lean() as any;
}
