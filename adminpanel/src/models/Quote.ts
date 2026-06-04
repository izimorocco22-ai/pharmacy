import mongoose, { Schema, Document } from 'mongoose';

export interface IQuoteItem {
  medicineName: string;
  quantity: number;
  unitPrice: number;
  totalPrice: number;
}

export interface IQuote extends Document {
  prescriptionId: mongoose.Types.ObjectId;
  pharmacyId: mongoose.Types.ObjectId;
  patientId: mongoose.Types.ObjectId;
  items: IQuoteItem[];
  subtotal: number;
  commissionRate: number;
  commissionAmount: number;
  deliveryFee: number;
  totalAmount: number;
  paymentMethod?: {
    name: string;
    details: string;
  };
  status: 'pending' | 'accepted' | 'rejected' | 'expired';
  rejectionReason?: string;
  expiresAt: Date;
  createdAt: Date;
  updatedAt: Date;
}

const QuoteSchema = new Schema<IQuote>(
  {
    prescriptionId: {
      type: Schema.Types.ObjectId,
      ref: 'Prescription',
      required: true,
    },
    pharmacyId: {
      type: Schema.Types.ObjectId,
      ref: 'Pharmacy',
      required: true,
    },
    patientId: {
      type: Schema.Types.ObjectId,
      ref: 'Patient',
      required: true,
    },
    items: [
      {
        medicineName: { type: String, required: true },
        quantity: { type: Number, required: true },
        unitPrice: { type: Number, required: true },
        totalPrice: { type: Number, required: true },
      },
    ],
    subtotal: {
      type: Number,
      default: 0,
    },
    commissionRate: {
      type: Number,
      default: 0,
    },
    commissionAmount: {
      type: Number,
      default: 0,
    },
    deliveryFee: {
      type: Number,
      required: true,
      default: 0,
    },
    totalAmount: {
      type: Number,
      default: 0,
    },
    paymentMethod: {
      name: { type: String },
      details: { type: String },
    },
    rejectionReason: {
      type: String,
      default: '',
    },
    status: {
      type: String,
      enum: ['pending', 'accepted', 'rejected', 'expired'],
      default: 'pending',
    },
    expiresAt: {
      type: Date,
      required: true,
      default: () => new Date(Date.now() + 60 * 60 * 1000), // 1 hour
    },
  },
  {
    timestamps: true,
  }
);

QuoteSchema.index({ prescriptionId: 1 });
QuoteSchema.index({ pharmacyId: 1 });
QuoteSchema.index({ patientId: 1 });
QuoteSchema.index({ status: 1 });

export default mongoose.models.Quote || mongoose.model<IQuote>('Quote', QuoteSchema);
