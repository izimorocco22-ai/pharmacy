import { NextRequest } from 'next/server';
import connectDB from '@/lib/mongodb';
import User from '@/models/User';
import { successResponse, errorResponse } from '@/lib/response';
import { generateOTP, storeOTP } from '@/lib/otp-store';
import { sendOTPSMS } from '@/lib/sms';

export const dynamic = 'force-dynamic';

export async function POST(request: NextRequest) {
  try {
    await connectDB();

    const { phone } = await request.json();

    if (!phone) {
      return errorResponse('Phone number is required');
    }

    // Verify patient exists with this phone
    const user = await User.findOne({ phone, role: 'patient' });
    if (!user) {
      return errorResponse('No patient account found with this phone number', 404);
    }

    if (!user.isActive) {
      return errorResponse('Account is deactivated', 403);
    }

    const otp = generateOTP();
    const useTwilioVerify = !!process.env.TWILIO_VERIFY_SERVICE_SID;

    await storeOTP(phone, otp, 10);

    const sent = await sendOTPSMS(phone, otp);

    if (!sent) {
      console.log(`\n🔐 OTP for ${phone}: ${otp} (SMS failed, showing in console)\n`);
    }

    return successResponse(
      { ...(sent ? {} : { otp }) },
      'OTP sent successfully'
    );
  } catch (error: any) {
    console.error('Patient send OTP error:', error);
    return errorResponse('Failed to send OTP', 500);
  }
}
