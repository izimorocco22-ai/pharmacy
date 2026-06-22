import { NextRequest } from 'next/server';
import connectDB from '@/lib/mongodb';
import User from '@/models/User';
import Pharmacy from '@/models/Pharmacy';
import Order from '@/models/Order';
import Notification from '@/models/Notification';
import { authenticateRequest, hashPassword, verifyPassword } from '@/lib/auth';
import { deleteFromCloudinary } from '@/lib/cloudinary';
import { successResponse, errorResponse, unauthorizedResponse } from '@/lib/response';

export const dynamic = 'force-dynamic';

// Order statuses that mean a pharmacy still has work in progress.
const ACTIVE_PHARMACY_STATUSES = [
  'payment_verification', 'confirmed', 'preparing', 'ready', 'assigned', 'picked_up', 'in_transit',
];

export async function GET(request: NextRequest) {
  try {
    const auth = await authenticateRequest(request);
    if (!auth || auth.role !== 'pharmacy') return unauthorizedResponse();

    await connectDB();

    const user = await User.findById(auth.userId).select('-password');
    if (!user) return errorResponse('User not found', 404);

    const pharmacy = await Pharmacy.findOne({ userId: auth.userId });

    return successResponse({
      user: {
        id: user._id,
        fullName: user.fullName,
        email: user.email,
        phone: user.phone,
        role: user.role,
        isVerified: user.isVerified,
        profileImage: user.profileImage,
      },
      pharmacy: pharmacy ? {
        pharmacyName: pharmacy.pharmacyName,
        licenseNumber: pharmacy.licenseNumber,
        address: pharmacy.address,
        location: pharmacy.location,
        isOpen: pharmacy.isOpen,
        rating: pharmacy.rating,
        totalOrders: pharmacy.totalOrders,
      } : null,
    });
  } catch (error: any) {
    return errorResponse('Failed to fetch profile', 500);
  }
}

export async function PUT(request: NextRequest) {
  try {
    const auth = await authenticateRequest(request);
    if (!auth || auth.role !== 'pharmacy') return unauthorizedResponse();

    await connectDB();

    const body = await request.json();
    const { fullName, phone, currentPassword, newPassword } = body;

    const user = await User.findById(auth.userId).select('+password');
    if (!user) return errorResponse('User not found', 404);

    // Change password flow
    if (currentPassword && newPassword) {
      const isValid = await verifyPassword(currentPassword, user.password);
      if (!isValid) return errorResponse('Current password is incorrect', 400);
      user.password = await hashPassword(newPassword);
      await user.save();
      return successResponse({}, 'Password updated successfully');
    }

    // Update profile
    if (fullName) user.fullName = fullName;
    if (phone) user.phone = phone;
    await user.save();

    return successResponse({
      user: {
        id: user._id,
        fullName: user.fullName,
        email: user.email,
        phone: user.phone,
        role: user.role,
        isVerified: user.isVerified,
      },
    }, 'Profile updated successfully');
  } catch (error: any) {
    return errorResponse('Failed to update profile', 500);
  }
}

// Permanently delete the authenticated pharmacy's account.
export async function DELETE(request: NextRequest) {
  try {
    const auth = await authenticateRequest(request);
    if (!auth || auth.role !== 'pharmacy') return unauthorizedResponse();

    await connectDB();

    const user = await User.findById(auth.userId);
    if (!user) return errorResponse('User not found', 404);

    const pharmacy = await Pharmacy.findOne({ userId: user._id });

    if (pharmacy) {
      // Block deletion while the pharmacy still has orders in progress
      const activeCount = await Order.countDocuments({
        pharmacyId: pharmacy._id,
        status: { $in: ACTIVE_PHARMACY_STATUSES },
      });
      if (activeCount > 0) {
        return errorResponse(
          'You have active orders. Please complete them before deleting your account.',
          400
        );
      }

      await Pharmacy.deleteOne({ _id: pharmacy._id });
    }

    await Notification.deleteMany({ userId: user._id });

    if (user.profileImagePublicId) {
      try { await deleteFromCloudinary(user.profileImagePublicId); } catch (_) {}
    }

    await User.deleteOne({ _id: user._id });

    return successResponse({ message: 'Account deleted successfully' });
  } catch (error: any) {
    console.error('Delete pharmacy account error:', error);
    return errorResponse('Failed to delete account', 500);
  }
}
