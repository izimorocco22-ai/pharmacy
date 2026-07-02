import mongoose, { Schema, Document } from 'mongoose';

// A payment/adjustment recorded against a pharmacy's commission dues.
// The outstanding balance = total commission (from delivered orders) minus the
// sum of all settlement amounts. A 'payment' is money the pharmacy paid us; an
// 'adjustment' is a manual correction/discount to what they should pay.
export interface IPharmacySettlement extends Document {
  pharmacyId: mongoose.Types.ObjectId;
  amount: number;
  type: 'payment' | 'adjustment';
  note?: string;
  month?: string; // optional 'YYYY-MM' label the payment covers
  createdAt: Date;
  updatedAt: Date;
}

const PharmacySettlementSchema = new Schema<IPharmacySettlement>(
  {
    pharmacyId: {
      type: Schema.Types.ObjectId,
      ref: 'Pharmacy',
      required: true,
      index: true,
    },
    amount: { type: Number, required: true },
    type: { type: String, enum: ['payment', 'adjustment'], default: 'payment' },
    note: { type: String, default: '' },
    month: { type: String, default: '' },
  },
  { timestamps: true }
);

export default mongoose.models.PharmacySettlement ||
  mongoose.model<IPharmacySettlement>('PharmacySettlement', PharmacySettlementSchema);
