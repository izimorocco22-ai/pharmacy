import mongoose, { Schema, Document } from 'mongoose';

export interface IPrescription extends Document {
  patientId: mongoose.Types.ObjectId;
  name?: string;
  imageUrl: string;
  imagePublicId?: string;
  medicines?: Array<{ name: string; quantity: number }>;
  status: 'pending' | 'quoted' | 'accepted' | 'rejected' | 'expired';
  deliveryAddress?: {
    address: string;
    location: {
      type: string;
      coordinates: [number, number];
    };
  };
  nearbyPharmacies: mongoose.Types.ObjectId[];
  assignedAt?: Date;
  expiresAt: Date;
  createdAt: Date;
  updatedAt: Date;
}

const PrescriptionSchema = new Schema<IPrescription>(
  {
    patientId: {
      type: Schema.Types.ObjectId,
      ref: 'Patient',
      required: true,
    },
    name: {
      type: String,
      default: '',
    },
    imageUrl: {
      type: String,
      default: '',
    },
    imagePublicId: {
      type: String,
    },
    medicines: [
      {
        name: { type: String, required: true },
        quantity: { type: Number, default: 1 },
      },
    ],
    status: {
      type: String,
      enum: ['pending', 'quoted', 'accepted', 'rejected', 'expired'],
      default: 'pending',
    },
    deliveryAddress: {
      address: { type: String },
      location: {
        type: { type: String, enum: ['Point'] },
        coordinates: { type: [Number] },
      },
    },
    nearbyPharmacies: [
      {
        type: Schema.Types.ObjectId,
        ref: 'Pharmacy',
      },
    ],
    assignedAt: {
      type: Date,
    },
    expiresAt: {
      type: Date,
      required: true,
      default: () => new Date(Date.now() + 24 * 60 * 60 * 1000), // 24 hours
    },
  },
  {
    timestamps: true,
  }
);

PrescriptionSchema.index({ patientId: 1 });
PrescriptionSchema.index({ status: 1 });
PrescriptionSchema.index({ expiresAt: 1 });
PrescriptionSchema.index({ nearbyPharmacies: 1 });
PrescriptionSchema.index({ 'deliveryAddress.location': '2dsphere' }, { sparse: true });

export default mongoose.models.Prescription || mongoose.model<IPrescription>('Prescription', PrescriptionSchema);
