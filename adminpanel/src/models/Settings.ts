import mongoose, { Schema, Document } from 'mongoose';

export interface ISettings extends Document {
  deliveryFee: number;
  commissionRate: number;
  minCommission: number;
  minOrderAmount: number;
  maxDeliveryRadius: number;
  minWithdrawalAmount: number;
  supportEmail: string;
  supportPhone: string;
  razorpayKeyId: string;
  razorpayKeySecret: string;
}

const SettingsSchema = new Schema<ISettings>(
  {
    deliveryFee: { type: Number, default: 20 },
    commissionRate: { type: Number, default: 15 },
    minCommission: { type: Number, default: 500 },
    minOrderAmount: { type: Number, default: 50 },
    maxDeliveryRadius: { type: Number, default: 10 },
    minWithdrawalAmount: { type: Number, default: 100 },
    supportEmail: { type: String, default: 'support@ordogo.com' },
    supportPhone: { type: String, default: '+212 600 000 000' },
    razorpayKeyId: { type: String, default: '' },
    razorpayKeySecret: { type: String, default: '' },
  },
  { timestamps: true }
);

export default mongoose.models.Settings || mongoose.model<ISettings>('Settings', SettingsSchema);
