import mongoose, { Schema, Document } from 'mongoose';

export interface IOrder extends Document {
  orderNumber: string;
  name?: string;
  prescriptionId: mongoose.Types.ObjectId;
  quoteId?: mongoose.Types.ObjectId;
  patientId: mongoose.Types.ObjectId;
  pharmacyId?: mongoose.Types.ObjectId;
  riderId?: mongoose.Types.ObjectId;
  items: Array<{
    medicineName: string;
    quantity: number;
    unitPrice: number;
    totalPrice: number;
  }>;
  subtotal: number;
  commissionRate: number;
  commissionAmount: number;
  deliveryFee: number;
  totalAmount: number;
  paymentMethod?: 'cash' | 'online' | 'manual';
  paymentMethodDetails?: {
    name: string;
    details: string;
  };
  paymentProofUrl?: string;
  paymentStatus: 'pending' | 'paid' | 'failed';
  status: 'pending' | 'payment_verification' | 'confirmed' | 'preparing' | 'ready' | 'assigned' | 'picked_up' | 'in_transit' | 'delivered' | 'cancelled';
  deliveryAddress: {
    address: string;
    location?: {
      type: string;
      coordinates: [number, number];
    };
  };
  pharmacyAddress?: {
    address: string;
    location?: {
      type: string;
      coordinates: [number, number];
    };
  };
  estimatedDeliveryTime?: Date;
  deliveredAt?: Date;
  cancelledAt?: Date;
  cancellationReason?: string;
  createdAt: Date;
  updatedAt: Date;
}

const OrderSchema = new Schema<IOrder>(
  {
    orderNumber: {
      type: String,
      required: true,
      unique: true,
    },
    name: {
      type: String,
      default: '',
    },
    prescriptionId: {
      type: Schema.Types.ObjectId,
      ref: 'Prescription',
    },
    quoteId: {
      type: Schema.Types.ObjectId,
      ref: 'Quote',
    },
    patientId: {
      type: Schema.Types.ObjectId,
      ref: 'Patient',
      required: true,
    },
    pharmacyId: {
      type: Schema.Types.ObjectId,
      ref: 'Pharmacy',
    },
    riderId: {
      type: Schema.Types.ObjectId,
      ref: 'Rider',
    },
    items: [
      {
        medicineName: { type: String, default: '' },
        quantity: { type: Number, default: 1 },
        unitPrice: { type: Number, default: 0 },
        totalPrice: { type: Number, default: 0 },
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
      default: 0,
    },
    totalAmount: {
      type: Number,
      default: 0,
    },
    paymentMethod: {
      type: String,
      enum: ['cash', 'online', 'manual'],
    },
    paymentMethodDetails: {
      name: { type: String },
      details: { type: String },
    },
    paymentProofUrl: {
      type: String,
      default: null,
    },
    paymentStatus: {
      type: String,
      enum: ['pending', 'paid', 'failed'],
      default: 'pending',
    },
    status: {
      type: String,
      enum: ['pending', 'payment_verification', 'confirmed', 'preparing', 'ready', 'assigned', 'picked_up', 'in_transit', 'delivered', 'cancelled'],
      default: 'pending',
    },
    deliveryAddress: {
      address: { type: String, default: '' },
      location: {
        type: { type: String, enum: ['Point'], default: 'Point' },
        coordinates: { type: [Number] },
      },
    },
    pharmacyAddress: {
      address: { type: String, default: '' },
      location: {
        type: { type: String, enum: ['Point'], default: 'Point' },
        coordinates: { type: [Number] },
      },
    },
    estimatedDeliveryTime: Date,
    deliveredAt: Date,
    cancelledAt: Date,
    cancellationReason: String,
  },
  {
    timestamps: true,
  }
);

OrderSchema.index({ orderNumber: 1 });
OrderSchema.index({ patientId: 1 });
OrderSchema.index({ pharmacyId: 1 });
OrderSchema.index({ riderId: 1 });
OrderSchema.index({ status: 1 });
OrderSchema.index({ 'pharmacyAddress.location': '2dsphere' }, { sparse: true });
OrderSchema.index({ 'deliveryAddress.location': '2dsphere' }, { sparse: true });

export default mongoose.models.Order || mongoose.model<IOrder>('Order', OrderSchema);
