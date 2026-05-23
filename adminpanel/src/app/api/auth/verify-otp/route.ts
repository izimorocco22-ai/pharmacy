import { NextRequest } from 'next/server';
import { successResponse, errorResponse } from '@/lib/response';
import { verifyOTP } from '@/lib/otp-store';
import { verifyOTPSMS } from '@/lib/sms';

export async function POST(request: NextRequest) {
  try {
    const { email, phone, otp } = await request.json();

    if ((!email && !phone) || !otp) {
      return errorResponse('Email/Phone and OTP are required');
    }

    const identifier = phone || email;
    let result: { valid: boolean; message: string };

    const useTwilioVerify = !!phone && !!process.env.TWILIO_VERIFY_SERVICE_SID;

    if (useTwilioVerify) {
      const isValid = await verifyOTPSMS(phone, otp);
      result = {
        valid: isValid,
        message: isValid ? 'OTP verified successfully' : 'Invalid or expired OTP'
      };
    } else {
      result = await verifyOTP(identifier, otp, false);
    }

    if (!result.valid) {
      return errorResponse(result.message);
    }

    return successResponse(
      { verified: true },
      result.message
    );
  } catch (error: any) {
    console.error('Verify OTP error:', error);
    return errorResponse('Failed to verify OTP', 500);
  }
}
