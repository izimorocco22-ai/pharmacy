import { NextRequest } from 'next/server';
import connectDB from '@/lib/mongodb';
import User from '@/models/User';
import Pharmacy from '@/models/Pharmacy';
import { generateToken } from '@/lib/auth';
import { successResponse, errorResponse } from '@/lib/response';
import { verifyOTP } from '@/lib/otp-store';
import { verifyOTPSMS } from '@/lib/sms';

export const dynamic = 'force-dynamic';

export async function POST(request: NextRequest) {
  try {
    await connectDB();

    const { phone: rawPhone, otp } = await request.json();

    if (!rawPhone || !otp) {
      return errorResponse('Phone and OTP are required');
    }

    const phone = rawPhone.trim();

    const user = await User.findOne({ phone, role: 'pharmacy' });
    if (!user) {
      return errorResponse('No pharmacy account found with this phone number', 404);
    }

    // Verify OTP
    const useTwilioVerify = !!process.env.TWILIO_VERIFY_SERVICE_SID;
    let isValid = false;

    // Google Play Console Review Bypass
    const isTestAccount = (phone === '+1234567890' || phone === '1234567890') && otp === '123456';
    
    if (isTestAccount) {
      isValid = true;
    } else if (useTwilioVerify) {
      isValid = await verifyOTPSMS(phone, otp);
    } else {
      const result = await verifyOTP(phone, otp, true);
      isValid = result.valid;
    }

    if (!isValid) {
      return errorResponse('Invalid or expired OTP');
    }

    // Get pharmacy approval status
    const pharmacy = await Pharmacy.findOne({ userId: user._id });
    const approvalStatus = pharmacy?.approvalStatus ?? 'pending';
    const adminNote = pharmacy?.adminNote ?? '';

    const token = generateToken({ userId: user._id.toString(), role: user.role });

    return successResponse({
      token,
      approvalStatus,
      adminNote,
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
    console.error('Pharmacy login error:', error);
    return errorResponse('Login failed', 500);
  }
}
