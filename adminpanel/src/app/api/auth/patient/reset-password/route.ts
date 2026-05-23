import { NextRequest } from 'next/server';
import connectDB from '@/lib/mongodb';
import User from '@/models/User';
import { successResponse, errorResponse } from '@/lib/response';
import { verifyOTP } from '@/lib/otp-store';
import { hashPassword } from '@/lib/auth';
import { verifyOTPSMS } from '@/lib/sms';

export async function POST(request: NextRequest) {
  try {
    await connectDB();

    const { phone, otp, newPassword } = await request.json();
    if (!phone || !otp || !newPassword) {
      return errorResponse('Phone number, OTP and new password are required');
    }

    if (newPassword.length < 6) {
      return errorResponse('Password must be at least 6 characters');
    }

    const identifier = phone;
    const useTwilioVerify = !!process.env.TWILIO_VERIFY_SERVICE_SID;

    if (useTwilioVerify) {
      const isValid = await verifyOTPSMS(phone, otp);
      if (!isValid) return errorResponse('Invalid or expired OTP');
    } else {
      const result = await verifyOTP(identifier, otp);
      if (!result.valid) return errorResponse(result.message);
    }

    const user = await User.findOne({ phone, role: 'patient' });
    if (!user) return errorResponse('No patient account found with this phone number');

    user.password = await hashPassword(newPassword);
    await user.save();

    return successResponse({}, 'Password reset successfully');
  } catch (error: any) {
    console.error('Patient reset password error:', error);
    return errorResponse('Failed to reset password', 500);
  }
}
