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

    const { phone: rawPhone } = await request.json();

    if (!rawPhone) {
      return errorResponse('Phone number is required');
    }

    const phone = rawPhone.trim();

    const user = await User.findOne({ phone, role: 'pharmacy' });
    if (!user) {
      return errorResponse('No pharmacy account found with this phone number', 404);
    }

    // Google Play Console Review Bypass
    if (phone === '+1234567890' || phone === '1234567890') {
      return successResponse({}, 'OTP sent successfully (Test Mode)');
    }

    const otp = generateOTP();
    const useTwilioVerify = !!process.env.TWILIO_VERIFY_SERVICE_SID;

    if (!useTwilioVerify) {
      await storeOTP(phone, otp, 10);
    }

    const sent = await sendOTPSMS(phone, otp);

    if (!sent) {
      console.log(`\n🔐 OTP for ${phone}: ${otp} (SMS failed, showing in console)\n`);
    }

    return successResponse(
      { ...(sent ? {} : { otp }) },
      'OTP sent successfully'
    );
  } catch (error: any) {
    console.error('Pharmacy send OTP error:', error);
    return errorResponse('Failed to send OTP', 500);
  }
}
