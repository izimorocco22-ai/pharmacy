import { NextRequest } from 'next/server';
import connectDB from '@/lib/mongodb';
import User from '@/models/User';
import Pharmacy from '@/models/Pharmacy';
import Rider from '@/models/Rider';
import { successResponse, errorResponse } from '@/lib/response';
import { generateOTP, storeOTP } from '@/lib/otp-store';
import { sendOTPSMS } from '@/lib/sms';

export async function POST(request: NextRequest) {
  try {
    await connectDB();

    const { phone: rawPhone, role } = await request.json();

    if (!rawPhone) {
      return errorResponse('Phone number is required');
    }

    const phone = rawPhone.trim();

    // Google Play Console Review Bypass
    if (phone === '+1234567890' || phone === '1234567890') {
      return successResponse({}, 'OTP sent to your phone (Test Mode)');
    }

    const existingUser = await User.findOne({ phone, ...(role ? { role } : {}) });

    if (existingUser) {
      let isRejected = false;
      if (role === 'pharmacy') {
        const pharmacy = await Pharmacy.findOne({ userId: existingUser._id });
        isRejected = pharmacy?.approvalStatus === 'rejected';
        if (isRejected) {
          await Pharmacy.deleteOne({ userId: existingUser._id });
          await User.deleteOne({ _id: existingUser._id });
        }
      } else if (role === 'rider') {
        const rider = await Rider.findOne({ userId: existingUser._id });
        isRejected = rider?.approvalStatus === 'rejected';
        if (isRejected) {
          await Rider.deleteOne({ userId: existingUser._id });
          await User.deleteOne({ _id: existingUser._id });
        }
      }
      if (!isRejected) {
        return errorResponse('User already exists with this phone number');
      }
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
      'OTP sent to your phone'
    );
  } catch (error: any) {
    console.error('Send OTP error:', error);
    return errorResponse('Failed to send OTP', 500);
  }
}
