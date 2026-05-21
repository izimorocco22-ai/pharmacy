import { NextRequest } from 'next/server';
import connectDB from '@/lib/mongodb';
import User from '@/models/User';
import Patient from '@/models/Patient';
import Pharmacy from '@/models/Pharmacy';
import Rider from '@/models/Rider';
import { hashPassword, generateToken } from '@/lib/auth';
import { successResponse, errorResponse } from '@/lib/response';

export const dynamic = 'force-dynamic';
// v2 - updated rider model

export async function POST(request: NextRequest) {
  try {
    await connectDB();

    const body = await request.json();
    const { fullName, email, phone, password, role, ...roleData } = body;

    // Validate required fields
    if (!fullName || !email || !phone || !password || !role) {
      return errorResponse('All fields are required');
    }

    // Check if user exists with same email AND same role
    const existingUser = await User.findOne({ email, role });
    if (existingUser) {
      // Allow re-registration if pharmacy was rejected
      if (role === 'pharmacy') {
        const existingPharmacy = await Pharmacy.findOne({ userId: existingUser._id });
        if (existingPharmacy?.approvalStatus === 'rejected') {
          await Pharmacy.deleteOne({ userId: existingUser._id });
          await User.deleteOne({ _id: existingUser._id });
        } else {
          return errorResponse('Account already exists with this email');
        }
      } else if (role === 'rider') {
        const existingRider = await Rider.findOne({ userId: existingUser._id });
        if (existingRider?.approvalStatus === 'rejected') {
          await Rider.deleteOne({ userId: existingUser._id });
          await User.deleteOne({ _id: existingUser._id });
        } else {
          return errorResponse('Account already exists with this email');
        }
      } else {
        return errorResponse('Account already exists with this email');
      }
    }

    // Check phone uniqueness across all roles (exclude same email+role re-registration)
    const existingPhone = await User.findOne({ phone, $or: [{ email: { $ne: email } }, { role: { $ne: role } }] });
    if (existingPhone) {
      return errorResponse('Account already exists with this phone number');
    }

    // Hash password
    const hashedPassword = await hashPassword(password);

    // Create user
    const user = await User.create({
      fullName,
      email,
      phone,
      password: hashedPassword,
      role,
      isVerified: true, // Set to true as registration happens after OTP verification
    });

    // Create role-specific profile
    if (role === 'patient') {
      await Patient.create({
        userId: user._id,
        addresses: [],
      });
    } else if (role === 'pharmacy') {
      await Pharmacy.create({
        userId: user._id,
        pharmacyName: roleData.pharmacyName,
        licenseNumber: roleData.licenseNumber,
        address: roleData.address,
        location: {
          type: 'Point',
          coordinates: roleData.coordinates,
        },
        approvalStatus: 'pending',
      });
      // Mark user inactive until admin approves
      await User.findByIdAndUpdate(user._id, { isActive: false });
    } else if (role === 'rider') {
      await Rider.create({
        userId: user._id,
        vehicleType: roleData.vehicleType || 'bike',
        vehicleNumber: roleData.vehicleNumber || '',
        licenseNumber: roleData.licenseNumber || '',
        licenseImageUrl: roleData.licenseImageUrl || '',
        approvalStatus: 'pending',
      });
      await User.findByIdAndUpdate(user._id, { isActive: false });
    }

    // Generate token
    const token = generateToken({ userId: user._id.toString(), role: user.role });

    return successResponse(
      {
        token,
        user: {
          id: user._id,
          fullName: user.fullName,
          email: user.email,
          phone: user.phone,
          role: user.role,
          isVerified: user.isVerified,
        },
      },
      'Registration successful',
      201
    );
  } catch (error: any) {
    console.error('Registration error:', error);
    // MongoDB duplicate key error
    if (error.code === 11000) {
      const field = Object.keys(error.keyPattern || {})[0];
      if (field === 'phone') return errorResponse('Account already exists with this phone number');
      return errorResponse('Account already exists with this email');
    }
    return errorResponse('Registration failed', 500);
  }
}
