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

    // Bypass for test user +11234567890 - always return success with fixed OTP
    if (phone === '+11234567890') {
      const testUser = await User.findOne({ phone, role: 'rider' });
      if (testUser) {
        return successResponse(
          { otp: '123456' },
          'OTP sent successfully'
        );
      }
    }

    const user = await User.findOne({ phone, role: 'rider' });
    if (!user) {
      return errorResponse('No rider account found with this phone number', 404);
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
    console.error('Rider send OTP error:', error);
    return errorResponse('Failed to send OTP', 500);
  }
}
