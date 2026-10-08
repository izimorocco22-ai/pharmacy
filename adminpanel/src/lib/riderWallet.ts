import mongoose from 'mongoose';
import Rider from '@/models/Rider';

// All rider wallet writes go through here and use atomic updates, never
// rider.save(), so a stale document can't overwrite the balance.

// Riders created before walletBalance existed have no such field; their
// unpaid balance is their lifetime earnings. Persist that once.
export async function ensureWalletBalance(riderId: string | mongoose.Types.ObjectId) {
  await Rider.updateOne(
    { _id: riderId, walletBalance: { $exists: false } },
    [{ $set: { walletBalance: { $ifNull: ['$totalEarnings', 0] } } }]
  );
  return Rider.findById(riderId).lean() as any;
}

// Add (positive) or remove (negative) money. A removal only succeeds if the
// balance covers it; returns null otherwise.
export async function incWalletBalance(riderId: string | mongoose.Types.ObjectId, amount: number) {
  await ensureWalletBalance(riderId);
  const filter: any = { _id: riderId };
  if (amount < 0) filter.walletBalance = { $gte: -amount };
  return Rider.findOneAndUpdate(filter, { $inc: { walletBalance: amount } }, { new: true }).lean() as any;
}

// Reset the balance to zero; returns the rider as it was before the reset
// (so walletBalance is the amount paid out), or null if not found.
export async function resetWalletBalance(riderId: string | mongoose.Types.ObjectId) {
  await ensureWalletBalance(riderId);
  return Rider.findOneAndUpdate(
    { _id: riderId },
    { $set: { walletBalance: 0 } },
    { new: false }
  ).lean() as any;
}
