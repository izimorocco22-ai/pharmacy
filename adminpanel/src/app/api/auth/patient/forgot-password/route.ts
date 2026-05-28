import { NextRequest } from 'next/server';
import connectDB from '@/lib/mongodb';
import User from '@/models/User';
import { successResponse, errorResponse } from '@/lib/response';
import { generateOTP, storeOTP } from '@/lib/otp-store';
import { sendOTPSMS } from '@/lib/sms';

export async function POST(request: NextRequest) {
  try {
    await connectDB();

    const { phone } = await request.json();
    if (!phone) return errorResponse('Phone number is required');

    const user = await User.findOne({ phone, role: 'patient' });
    
    if (!user) {
      return errorResponse('No patient account found with this phone number');
    }

    const identifier = phone;
    const otp = generateOTP();
    const useTwilioVerify = !!process.env.TWILIO_VERIFY_SERVICE_SID;

    if (!useTwilioVerify) {
      await storeOTP(identifier, otp, 10);
    }

    const sent = await sendOTPSMS(phone, otp);

    if (!sent) {
      console.log(`\n🔐 Reset OTP for ${identifier}: ${otp}\n`);
    }

    return successResponse(
      { ...(sent ? {} : { otp }) },
      'OTP sent to your phone'
    );
  } catch (error: any) {
    console.error('Patient forgot password error:', error);
    return errorResponse('Failed to send OTP', 500);
  }
}
