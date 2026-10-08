import { NextRequest } from 'next/server';
import connectDB from '@/lib/mongodb';
import Order from '@/models/Order';
import Rider from '@/models/Rider';
import RiderWalletTransaction from '@/models/RiderWalletTransaction';
import { authenticateRequest } from '@/lib/auth';
import { successResponse, errorResponse, unauthorizedResponse } from '@/lib/response';

export const dynamic = 'force-dynamic';

export async function GET(request: NextRequest) {
  try {
    const auth = await authenticateRequest(request);
    if (!auth || auth.role !== 'rider') return unauthorizedResponse();

    await connectDB();

    const rider = await Rider.findOne({ userId: auth.userId }).lean() as any;
    if (!rider) return errorResponse('Rider not found', 404);

    const orders = await Order.find({
      riderId: rider._id,
      status: { $in: ['delivered', 'picked_up', 'in_transit', 'assigned'] },
    })
      .sort({ createdAt: -1 })
      .limit(50)
      .lean() as any[];

    const adjustments = await RiderWalletTransaction.find({
      riderId: rider._id,
      type: { $in: ['add', 'deduct'] },
    })
      .sort({ createdAt: -1 })
      .limit(50)
      .lean() as any[];

    const result = orders.map((o: any) => ({
      id: o._id?.toString(),
      orderNumber: o.orderNumber || '',
      status: o.status,
      pickupAddress: o.pharmacyAddress?.address || '',
      deliveryAddress: o.deliveryAddress?.address || '',
      deliveryFee: o.deliveryFee || 0,
      deliveredAt: o.deliveredAt || o.updatedAt,
      createdAt: o.createdAt,
    }));

    return successResponse({
      orders: result,
      totalEarnings: rider.totalEarnings || 0,
      // Same figure as totalEarnings; kept so older app builds that read
      // walletBalance show the right amount
      walletBalance: rider.totalEarnings || 0,
      // Admin add/deduct entries, shown in the app's earnings history
      adjustments: adjustments.map((a: any) => ({
        id: a._id?.toString(),
        type: a.type,
        amount: a.amount,
        note: a.note || '',
        createdAt: a.createdAt,
      })),
      totalDeliveries: rider.totalDeliveries || 0,
    });
  } catch (error) {
    console.error('Rider orders error:', error);
    return errorResponse('Failed to fetch orders', 500);
  }
}
