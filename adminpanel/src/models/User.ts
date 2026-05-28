import mongoose, { Schema, Document } from 'mongoose';

export interface IUser extends Document {
  fullName: string;
  email?: string;
  phone: string;
  password: string;
  role: 'patient' | 'pharmacy' | 'rider' | 'admin';
  isVerified: boolean;
  isActive: boolean;
  profileImage?: string;
  profileImagePublicId?: string;
  fcmToken?: string;
  createdAt: Date;
  updatedAt: Date;
}

const UserSchema = new Schema<IUser>(
  {
    fullName: {
      type: String,
      required: true,
      trim: true,
    },
    email: {
      type: String,
      required: false,
      lowercase: true,
      trim: true,
    },
    phone: {
      type: String,
      required: true,
    },
    password: {
      type: String,
      required: true,
      select: false,
    },
    role: {
      type: String,
      enum: ['patient', 'pharmacy', 'rider', 'admin'],
      required: true,
    },
    isVerified: {
      type: Boolean,
      default: false,
    },
    isActive: {
      type: Boolean,
      default: true,
    },
    fcmToken: {
      type: String,
    },
    profileImage: {
      type: String,
    },
    profileImagePublicId: {
      type: String,
    },
  },
  {
    timestamps: true,
  }
);

UserSchema.index({ phone: 1, role: 1 }, { unique: true });
UserSchema.index({ role: 1 });

export default mongoose.models.User || mongoose.model<IUser>('User', UserSchema);
