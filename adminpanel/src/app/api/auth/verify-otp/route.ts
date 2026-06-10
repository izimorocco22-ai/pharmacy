import { NextRequest } from 'next/server';
import { successResponse, errorResponse } from '@/lib/response';
import { verifyOTP } from '@/lib/otp-store';
import { verifyOTPSMS } from '@/lib/sms';

export async function POST(request: NextRequest) {
  try {
    const { phone, otp } = await request.json();

    if (!phone || !otp) {
      return errorResponse('Phone and OTP are required');
    }

    // Google Play Console Review Bypass
    if (phone === '+1234567890' && otp === '123456') {
      return successResponse({ verified: true }, 'Test OTP verified successfully');
    }

    const useTwilioVerify = !!process.env.TWILIO_VERIFY_SERVICE_SID;
    let result: { valid: boolean; message: string };

    if (useTwilioVerify) {
      const isValid = await verifyOTPSMS(phone, otp);
      result = {
        valid: isValid,
        message: isValid ? 'OTP verified successfully' : 'Invalid or expired OTP'
      };
    } else {
      result = await verifyOTP(phone, otp, true);
    }

    if (!result.valid) {
      return errorResponse(result.message);
    }

    return successResponse({ verified: true }, result.message);
  } catch (error: any) {
    console.error('Verify OTP error:', error);
    return errorResponse('Failed to verify OTP', 500);
  }
}
