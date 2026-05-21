import { NextRequest } from 'next/server';
import connectDB from '@/lib/mongodb';
import User from '@/models/User';
import Pharmacy from '@/models/Pharmacy';
import Rider from '@/models/Rider';
import { successResponse, errorResponse } from '@/lib/response';
import { generateOTP, storeOTP } from '@/lib/otp-store';
import { sendOTPEmail } from '@/lib/email';
import { sendOTPSMS } from '@/lib/sms';

export async function POST(request: NextRequest) {
  try {
    await connectDB();

    const { email, phone, role } = await request.json();

    if (!email && !phone) {
      return errorResponse('Email or Phone is required');
    }

    const identifier = phone || email;

    // Check if user already exists with same identifier AND role
    const query = phone ? { phone } : { email };
    const existingUser = await User.findOne({ ...query, ...(role ? { role } : {}) });
    
    if (existingUser) {
      // Allow re-registration if previously rejected
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
        return errorResponse(`User already exists with this ${phone ? 'phone' : 'email'}`);
      }
    }

    // Generate and store OTP
    const otp = generateOTP();
    await storeOTP(identifier, otp, 10);

    let sent = false;
    let method = '';

    if (phone) {
      sent = await sendOTPSMS(phone, otp);
      method = 'phone';
    } else {
      sent = await sendOTPEmail(email, otp);
      method = 'email';
    }

    if (!sent) {
      console.log(`\n🔐 OTP for ${identifier}: ${otp} (${method} failed, showing in console)\n`);
    }

    return successResponse(
      { 
        message: 'OTP sent successfully',
        // Only include OTP in response if sending failed (for development)
        ...(sent ? {} : { otp })
      },
      `OTP sent to your ${method}`
    );
  } catch (error: any) {
    console.error('Send OTP error:', error);
    return errorResponse('Failed to send OTP', 500);
  }
}
