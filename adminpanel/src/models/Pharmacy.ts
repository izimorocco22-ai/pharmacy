import mongoose, { Schema, Document } from 'mongoose';

export interface IPharmacy extends Document {
  userId: mongoose.Types.ObjectId;
  pharmacyName: string;
  licenseNumber: string;
  address: string;
  location: {
    type: string;
    coordinates: [number, number];
  };
  operatingHours: {
    open: string;
    close: string;
  };
  isOpen: boolean;
  rating: number;
  totalOrders: number;
  acceptanceRate: number;
  approvalStatus: 'pending' | 'approved' | 'rejected';
  adminNote?: string;
  createdAt: Date;
  updatedAt: Date;
}

const PharmacySchema = new Schema<IPharmacy>(
  {
    userId: {
      type: Schema.Types.ObjectId,
      ref: 'User',
      required: true,
      unique: true,
    },
    pharmacyName: {
      type: String,
      required: true,
    },
    licenseNumber: {
      type: String,
      required: true,
      unique: true,
    },
    address: {
      type: String,
      required: true,
    },
    location: {
      type: { type: String, enum: ['Point'], default: 'Point' },
      coordinates: {
        type: [Number],
        required: true,
      },
    },
    operatingHours: {
      open: { type: String, default: '08:00' },
      close: { type: String, default: '22:00' },
    },
    isOpen: {
      type: Boolean,
      default: true,
    },
    rating: {
      type: Number,
      default: 5.0,
      min: 0,
      max: 5,
    },
    totalOrders: {
      type: Number,
      default: 0,
    },
    acceptanceRate: {
      type: Number,
      default: 100,
      min: 0,
      max: 100,
    },
    approvalStatus: {
      type: String,
      enum: ['pending', 'approved', 'rejected'],
      default: 'pending',
    },
    adminNote: {
      type: String,
      default: '',
    },
  },
  {
    timestamps: true,
  }
);

PharmacySchema.index({ location: '2dsphere' });
PharmacySchema.index({ isOpen: 1 });

export default mongoose.models.Pharmacy || mongoose.model<IPharmacy>('Pharmacy', PharmacySchema);
