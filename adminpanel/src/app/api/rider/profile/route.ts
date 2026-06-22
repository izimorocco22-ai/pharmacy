import { NextRequest } from 'next/server';
import connectDB from '@/lib/mongodb';
import User from '@/models/User';
import Rider from '@/models/Rider';
import Order from '@/models/Order';
import Notification from '@/models/Notification';
import { authenticateRequest } from '@/lib/auth';
import { deleteFromCloudinary } from '@/lib/cloudinary';
import { successResponse, errorResponse, unauthorizedResponse } from '@/lib/response';

export const dynamic = 'force-dynamic';

// Active delivery statuses a rider cannot abandon by deleting their account.
const ACTIVE_RIDER_STATUSES = ['assigned', 'picked_up', 'in_transit'];

export async function GET(request: NextRequest) {
  try {
    const auth = await authenticateRequest(request);
    if (!auth || auth.role !== 'rider') return unauthorizedResponse();

    await connectDB();

    const rider = await Rider.findOne({ userId: auth.userId }).lean() as any;
    if (!rider) return errorResponse('Rider not found', 404);

    return successResponse({ rider });
  } catch (error) {
    console.error(error);
    return errorResponse('Failed to fetch rider profile', 500);
  }
}

// Permanently delete the authenticated rider's account.
export async function DELETE(request: NextRequest) {
  try {
    const auth = await authenticateRequest(request);
    if (!auth || auth.role !== 'rider') return unauthorizedResponse();

    await connectDB();

    const user = await User.findById(auth.userId);
    if (!user) return errorResponse('User not found', 404);

    const rider = await Rider.findOne({ userId: user._id });

    if (rider) {
      // Block deletion while the rider still has a delivery in progress
      const activeCount = await Order.countDocuments({
        riderId: rider._id,
        status: { $in: ACTIVE_RIDER_STATUSES },
      });
      if (activeCount > 0) {
        return errorResponse(
          'You have active deliveries. Please complete them before deleting your account.',
          400
        );
      }

      // Detach the rider from any historical orders so records stay intact
      await Order.updateMany({ riderId: rider._id }, { $unset: { riderId: '' } });
      await Rider.deleteOne({ _id: rider._id });
    }

    await Notification.deleteMany({ userId: user._id });

    if (user.profileImagePublicId) {
      try { await deleteFromCloudinary(user.profileImagePublicId); } catch (_) {}
    }

    await User.deleteOne({ _id: user._id });

    return successResponse({ message: 'Account deleted successfully' });
  } catch (error) {
    console.error('Delete rider account error:', error);
    return errorResponse('Failed to delete account', 500);
  }
}
