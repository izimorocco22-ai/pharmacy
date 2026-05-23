import mongoose, { Schema, Document } from 'mongoose';

export interface IPatient extends Document {
  userId: mongoose.Types.ObjectId;
  addresses: Array<{
    label: string;
    address: string;
    city?: string;
    state?: string;
    zipCode?: string;
    location: {
      type: string;
      coordinates: [number, number];
    };
    isDefault: boolean;
  }>;
  totalOrders: number;
  createdAt: Date;
  updatedAt: Date;
}

const PatientSchema = new Schema<IPatient>(
  {
    userId: {
      type: Schema.Types.ObjectId,
      ref: 'User',
      required: true,
      unique: true,
    },
    addresses: [
      {
        label: { type: String, required: true },
        address: { type: String, required: true },
        city: { type: String },
        state: { type: String },
        zipCode: { type: String },
        location: {
          type: { type: String, enum: ['Point'], default: 'Point' },
          coordinates: { type: [Number], required: true },
        },
        isDefault: { type: Boolean, default: false },
      },
    ],
    totalOrders: {
      type: Number,
      default: 0,
    },
  },
  {
    timestamps: true,
  }
);

PatientSchema.index({ 'addresses.location': '2dsphere' });

export default mongoose.models.Patient || mongoose.model<IPatient>('Patient', PatientSchema);
