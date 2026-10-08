import mongoose, { Schema, Document } from 'mongoose';

// A manual change to a rider's earnings made by the admin. The amount itself
// lives on Rider.totalEarnings; these rows are the audit trail and are also
// listed in the rider app's earnings history.
// 'deduct' = admin took money out (penalty, payout, etc.),
// 'add' = admin credited money (bonus, correction),
// 'payout' = legacy full payout from the removed Mark Paid button.
export interface IRiderWalletTransaction extends Document {
  riderId: mongoose.Types.ObjectId;
  type: 'deduct' | 'add' | 'payout';
  amount: number; // always positive; type decides the direction
  balanceAfter: number; // rider's totalEarnings after this change
  note?: string;
  createdAt: Date;
  updatedAt: Date;
}

const RiderWalletTransactionSchema = new Schema<IRiderWalletTransaction>(
  {
    riderId: {
      type: Schema.Types.ObjectId,
      ref: 'Rider',
      required: true,
      index: true,
    },
    type: { type: String, enum: ['deduct', 'add', 'payout'], required: true },
    amount: { type: Number, required: true },
    balanceAfter: { type: Number, required: true },
    note: { type: String, default: '' },
  },
  { timestamps: true }
);

export default mongoose.models.RiderWalletTransaction ||
  mongoose.model<IRiderWalletTransaction>('RiderWalletTransaction', RiderWalletTransactionSchema);
