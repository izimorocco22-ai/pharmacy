import mongoose, { Schema, Document } from 'mongoose';

// A manual change to a rider's wallet made by the admin. The wallet balance
// itself lives on Rider.walletBalance; these rows are the audit trail.
// 'deduct' = admin took money out (penalty, cash collected, etc.),
// 'add' = admin credited money (bonus, correction),
// 'payout' = admin paid out the whole balance (Mark Paid).
export interface IRiderWalletTransaction extends Document {
  riderId: mongoose.Types.ObjectId;
  type: 'deduct' | 'add' | 'payout';
  amount: number; // always positive; type decides the direction
  balanceAfter: number;
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
