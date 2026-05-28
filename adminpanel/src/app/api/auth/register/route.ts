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
    const { fullName, phone, password, role, ...roleData } = body;

    // Validate required fields
    if (!fullName || !phone || !password || !role) {
      return errorResponse('All fields are required');
    }

    // Check phone uniqueness within the same role only
    const existingPhone = await User.findOne({ phone, role });
    if (existingPhone) {
      let isRejected = false;
      if (role === 'pharmacy') {
        const existingPharmacy = await Pharmacy.findOne({ userId: existingPhone._id });
        isRejected = existingPharmacy?.approvalStatus === 'rejected';
      } else if (role === 'rider') {
        const existingRider = await Rider.findOne({ userId: existingPhone._id });
        isRejected = existingRider?.approvalStatus === 'rejected';
      }

      if (!isRejected) {
        return errorResponse('Account already exists with this phone number');
      }
    }

    // Hash password
    const hashedPassword = await hashPassword(password);

    // Create user
    const user = await User.create({
      fullName,
      phone,
      password: hashedPassword,
      role,
      isVerified: true,
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
      return errorResponse('Account already exists with this phone number');
    }
    return errorResponse('Registration failed', 500);
  }
}
