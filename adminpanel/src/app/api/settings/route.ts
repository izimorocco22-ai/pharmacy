import { NextRequest } from 'next/server';
import connectDB from '@/lib/mongodb';
import Settings from '@/models/Settings';
import { successResponse, errorResponse } from '@/lib/response';

export const dynamic = 'force-dynamic';

const defaults = {
  deliveryFee: 20,
  commissionRate: 15,
  minCommission: 500,
  minOrderAmount: 50,
  maxDeliveryRadius: 10,
  minWithdrawalAmount: 100,
  supportEmail: 'support@ordogo.com',
  supportPhone: '+212 600 000 000',
  razorpayKeyId: '',
  razorpayKeySecret: '',
};

async function getSettings() {
  await connectDB();
  let settings = await Settings.findOne().lean() as any;
  if (!settings) {
    settings = await Settings.create(defaults);
  }
  return settings;
}

export async function GET() {
  try {
    const settings = await getSettings();
    return successResponse({
      deliveryFee: settings.deliveryFee,
      commissionRate: settings.commissionRate ?? 15,
      minCommission: settings.minCommission ?? 500,
      minOrderAmount: settings.minOrderAmount,
      maxDeliveryRadius: settings.maxDeliveryRadius,
      minWithdrawalAmount: settings.minWithdrawalAmount ?? 100,
      supportEmail: settings.supportEmail,
      supportPhone: settings.supportPhone,
      razorpayKeyId: settings.razorpayKeyId || '',
      // secret masked for display, full value only used server-side
      razorpayKeySecret: settings.razorpayKeySecret ? '••••••••••••••••••••' : '',
    });
  } catch (error: any) {
    console.error('Get settings error:', error);
    return errorResponse('Failed to fetch settings', 500);
  }
}

export async function PUT(request: NextRequest) {
  try {
    await connectDB();
    const body = await request.json();

    // Don't overwrite secret if masked placeholder was sent back
    if (body.razorpayKeySecret?.includes('•')) {
      delete body.razorpayKeySecret;
    }

    // Commission rate and minimum commission are fixed business rules — the
    // admin can view them but not change them here.
    delete body.commissionRate;
    delete body.minCommission;

    const settings = await Settings.findOneAndUpdate(
      {},
      { $set: body },
      { new: true, upsert: true }
    ).lean() as any;

    return successResponse({
      deliveryFee: settings.deliveryFee,
      commissionRate: settings.commissionRate ?? 15,
      minCommission: settings.minCommission ?? 500,
      minOrderAmount: settings.minOrderAmount,
      maxDeliveryRadius: settings.maxDeliveryRadius,
      minWithdrawalAmount: settings.minWithdrawalAmount ?? 100,
      supportEmail: settings.supportEmail,
      supportPhone: settings.supportPhone,
      razorpayKeyId: settings.razorpayKeyId || '',
      razorpayKeySecret: settings.razorpayKeySecret ? '••••••••••••••••••••' : '',
    }, 'Settings updated successfully');
  } catch (error: any) {
    console.error('Update settings error:', error);
    return errorResponse('Failed to update settings', 500);
  }
}
