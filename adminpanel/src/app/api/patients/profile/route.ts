import { NextRequest } from 'next/server';
import connectDB from '@/lib/mongodb';
import User from '@/models/User';
import Patient from '@/models/Patient';
import Prescription from '@/models/Prescription';
import Quote from '@/models/Quote';
import Order from '@/models/Order';
import Notification from '@/models/Notification';
import { authenticateRequest } from '@/lib/auth';
import { deleteFromCloudinary } from '@/lib/cloudinary';
import { successResponse, errorResponse } from '@/lib/response';

export const dynamic = 'force-dynamic';

export async function GET(request: NextRequest) {
  try {
    await connectDB();
    const decoded = await authenticateRequest(request);
    
    if (!decoded) {
      return errorResponse('Unauthorized', 401);
    }

    const user = await User.findById(decoded.userId).select('-password');
    if (!user) {
      return errorResponse('User not found', 404);
    }

    return successResponse({ user });
  } catch (error: any) {
    console.error('Get profile error:', error);
    return errorResponse('Failed to fetch profile', 500);
  }
}

export async function PUT(request: NextRequest) {
  try {
    await connectDB();
    const decoded = await authenticateRequest(request);
    
    if (!decoded) {
      return errorResponse('Unauthorized', 401);
    }

    const body = await request.json();
    const { fullName, phone, profileImageUrl, profileImagePublicId } = body;

    // Get current user to check for existing profile image
    const currentUser = await User.findById(decoded.userId);
    if (!currentUser) {
      return errorResponse('User not found', 404);
    }

    const updateData: any = {};
    if (fullName) updateData.fullName = fullName;
    if (phone) updateData.phone = phone;
    
    // Handle profile image update
    if (profileImageUrl) {
      updateData.profileImage = profileImageUrl;
      if (profileImagePublicId) {
        updateData.profileImagePublicId = profileImagePublicId;
      }
    }

    const user = await User.findByIdAndUpdate(
      decoded.userId,
      { $set: updateData },
      { new: true, runValidators: true }
    ).select('-password');

    if (!user) {
      return errorResponse('User not found', 404);
    }

    return successResponse({
      message: 'Profile updated successfully',
      user
    });
  } catch (error: any) {
    console.error('Update profile error:', error);
    if (error.code === 11000) {
      return errorResponse('Phone number already in use', 400);
    }
    return errorResponse('Failed to update profile', 500);
  }
}

// Permanently delete the authenticated patient's account and all their data.
export async function DELETE(request: NextRequest) {
  try {
    await connectDB();
    const decoded = await authenticateRequest(request);

    if (!decoded) {
      return errorResponse('Unauthorized', 401);
    }

    const user = await User.findById(decoded.userId);
    if (!user) {
      return errorResponse('User not found', 404);
    }
    if (user.role !== 'patient') {
      return errorResponse('Forbidden', 403);
    }

    const patient = await Patient.findOne({ userId: user._id });

    if (patient) {
      // Remove the patient's prescriptions (and their Cloudinary images)
      const prescriptions = await Prescription.find({ patientId: patient._id }).select('imagePublicId');
      for (const p of prescriptions) {
        if (p.imagePublicId) {
          try { await deleteFromCloudinary(p.imagePublicId); } catch (_) {}
        }
      }
      await Prescription.deleteMany({ patientId: patient._id });
      await Quote.deleteMany({ patientId: patient._id });
      await Order.deleteMany({ patientId: patient._id });
      await Patient.deleteOne({ _id: patient._id });
    }

    // Remove the user's notifications
    await Notification.deleteMany({ userId: user._id });

    // Remove the profile image from Cloudinary
    if (user.profileImagePublicId) {
      try { await deleteFromCloudinary(user.profileImagePublicId); } catch (_) {}
    }

    // Finally remove the user account itself
    await User.deleteOne({ _id: user._id });

    return successResponse({ message: 'Account deleted successfully' });
  } catch (error: any) {
    console.error('Delete account error:', error);
    return errorResponse('Failed to delete account', 500);
  }
}
