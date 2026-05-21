import mongoose, { Schema, Document } from 'mongoose';

export interface IOtp extends Document {
  identifier: string; // email or phone
  otp: string;
  expiresAt: Date;
}

const OtpSchema = new Schema<IOtp>({
  identifier: { type: String, required: true, lowercase: true, trim: true },
  otp: { type: String, required: true },
  expiresAt: { type: Date, required: true },
});

// TTL index — MongoDB auto-deletes the document after expiresAt
OtpSchema.index({ expiresAt: 1 }, { expireAfterSeconds: 0 });
OtpSchema.index({ identifier: 1 });

export default mongoose.models.Otp || mongoose.model<IOtp>('Otp', OtpSchema);
