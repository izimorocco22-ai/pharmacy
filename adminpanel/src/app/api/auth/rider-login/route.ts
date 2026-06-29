import { NextRequest } from 'next/server';
import connectDB from '@/lib/mongodb';
import User from '@/models/User';
import Rider from '@/models/Rider';
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

    const user = await User.findOne({ phone, role: 'rider' });
    if (!user) {
      return errorResponse('No rider account found with this phone number', 404);
    }

    // Bypass for test user +11234567890 with OTP 123456
    let isValid = false;
    if (phone === '+11234567890' && otp === '123456') {
      isValid = true;
    } else {
      // Verify OTP normally for other users
      const useTwilioVerify = !!process.env.TWILIO_VERIFY_SERVICE_SID;
      if (useTwilioVerify) {
        isValid = await verifyOTPSMS(phone, otp);
      } else {
        const result = await verifyOTP(phone, otp, true);
        isValid = result.valid;
      }
    }

    if (!isValid) {
      return errorResponse('Invalid or expired OTP');
    }

    // Get rider approval status
    const rider = await Rider.findOne({ userId: user._id });
    const approvalStatus = rider?.approvalStatus ?? 'pending';
    const adminNote = rider?.adminNote ?? '';

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
    console.error('Rider login error:', error);
    return errorResponse('Login failed', 500);
  }
}
