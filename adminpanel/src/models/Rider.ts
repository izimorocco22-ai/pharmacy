import mongoose, { Schema, Document } from 'mongoose';

export interface IRider extends Document {
  userId: mongoose.Types.ObjectId;
  vehicleType: 'bike' | 'scooter' | 'car';
  vehicleNumber: string;
  licenseNumber: string;
  licenseImageUrl?: string;
  approvalStatus: 'pending' | 'approved' | 'rejected';
  adminNote?: string;
  currentLocation?: {
    type: string;
    coordinates: [number, number];
  };
  isAvailable: boolean;
  isOnline: boolean;
  rating: number;
  totalDeliveries: number;
  totalEarnings: number;
  createdAt: Date;
  updatedAt: Date;
}

const RiderSchema = new Schema<IRider>(
  {
    userId: {
      type: Schema.Types.ObjectId,
      ref: 'User',
      required: true,
    },
    vehicleType: {
      type: String,
      enum: ['bike', 'scooter', 'car'],
      required: true,
    },
    vehicleNumber: {
      type: String,
      default: '',
    },
    licenseNumber: {
      type: String,
      required: true,
    },
    licenseImageUrl: {
      type: String,
    },
    approvalStatus: {
      type: String,
      enum: ['pending', 'approved', 'rejected'],
      default: 'pending',
    },
    adminNote: {
      type: String,
    },
    currentLocation: {
      type: { type: String, enum: ['Point'] },
      coordinates: { type: [Number] },
    },
    isAvailable: {
      type: Boolean,
      default: true,
    },
    isOnline: {
      type: Boolean,
      default: false,
    },
    rating: {
      type: Number,
      default: 5.0,
      min: 0,
      max: 5,
    },
    totalDeliveries: {
      type: Number,
      default: 0,
    },
    // The rider's one money figure: deliveries add to it and the admin can
    // add/deduct. Change it only through lib/riderWallet.ts (atomic $inc).
    totalEarnings: {
      type: Number,
      default: 0,
    },
  },
  {
    timestamps: true,
  }
);

RiderSchema.index({ currentLocation: '2dsphere' }, { sparse: true });
RiderSchema.index({ userId: 1 }, { unique: true });
RiderSchema.index({ isAvailable: 1, isOnline: 1 });

export default mongoose.models.Rider || mongoose.model<IRider>('Rider', RiderSchema);
