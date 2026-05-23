import { NextRequest } from 'next/server';
import connectDB from '@/lib/mongodb';
import User from '@/models/User';
import { generateToken } from '@/lib/auth';
import { successResponse, errorResponse } from '@/lib/response';
import { verifyOTP } from '@/lib/otp-store';
import { verifyOTPSMS } from '@/lib/sms';

export const dynamic = 'force-dynamic';

export async function POST(request: NextRequest) {
  try {
    await connectDB();

    const { phone, otp } = await request.json();

    if (!phone || !otp) {
      return errorResponse('Phone and OTP are required');
    }

    // Check patient exists with this phone
    const user = await User.findOne({ phone, role: 'patient' });
    if (!user) {
      return errorResponse('No patient account found with this phone number', 404);
    }

    if (!user.isActive) {
      return errorResponse('Account is deactivated', 403);
    }

    // Verify OTP
    const useTwilioVerify = !!process.env.TWILIO_VERIFY_SERVICE_SID;
    let isValid = false;

    if (useTwilioVerify) {
      isValid = await verifyOTPSMS(phone, otp);
    } else {
      const result = await verifyOTP(phone, otp, false);
      isValid = result.valid;
    }

    if (!isValid) {
      return errorResponse('Invalid or expired OTP');
    }

    const token = generateToken({ userId: user._id.toString(), role: user.role });

    return successResponse({
      token,
      user: {
        id: user._id,
        fullName: user.fullName,
        email: user.email,
        phone: user.phone,
        role: user.role,
        isVerified: user.isVerified,
      },
    });
  } catch (error: any) {
    console.error('Patient login error:', error);
    return errorResponse('Login failed', 500);
  }
}
