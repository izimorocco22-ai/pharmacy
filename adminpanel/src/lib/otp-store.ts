import connectDB from './mongodb';
import OtpModel from '@/models/Otp';

export function generateOTP(): string {
  return Math.floor(100000 + Math.random() * 900000).toString();
}

export async function storeOTP(identifier: string, otp: string, expiryMinutes: number = 10): Promise<void> {
  await connectDB();
  const expiresAt = new Date(Date.now() + expiryMinutes * 60 * 1000);
  await OtpModel.findOneAndUpdate(
    { identifier },
    { otp, expiresAt },
    { upsert: true, new: true }
  );
  console.log(`[OTP] Stored for ${identifier}: ${otp} (expires in ${expiryMinutes} min)`);
}

export async function verifyOTP(identifier: string, otp: string, deleteAfterVerify: boolean = true): Promise<{ valid: boolean; message: string }> {
  await connectDB();
  const stored = await OtpModel.findOne({ identifier });

  if (!stored) {
    return { valid: false, message: 'OTP not found or expired' };
  }

  if (Date.now() > stored.expiresAt.getTime()) {
    await OtpModel.deleteOne({ identifier });
    return { valid: false, message: 'OTP has expired' };
  }

  if (stored.otp !== otp) {
    return { valid: false, message: 'Invalid OTP' };
  }

  if (deleteAfterVerify) {
    await OtpModel.deleteOne({ identifier });
    console.log(`[OTP] ✅ Verified and removed for ${identifier}`);
  } else {
    console.log(`[OTP] ✅ Verified (kept) for ${identifier}`);
  }
  return { valid: true, message: 'OTP verified successfully' };
}
