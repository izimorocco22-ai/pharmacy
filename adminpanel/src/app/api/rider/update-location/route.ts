import { NextRequest } from 'next/server';
import connectDB from '@/lib/mongodb';
import Rider from '@/models/Rider';
import { authenticateRequest } from '@/lib/auth';
import { successResponse, errorResponse, unauthorizedResponse } from '@/lib/response';

export const dynamic = 'force-dynamic';

export async function PUT(request: NextRequest) {
  try {
    const auth = await authenticateRequest(request);
    if (!auth || auth.role !== 'rider') return unauthorizedResponse();

    await connectDB();

    const { lat, lng, isOnline } = await request.json();

    // Either a location update, an online-status update, or both. A location
    // ping must not be required to carry a status, and a status toggle must
    // not be required to carry (and overwrite) the location.
    if (lat === undefined && lng === undefined && isOnline === undefined) {
      return errorResponse('Nothing to update');
    }

    const update: any = {};

    // Only touch the stored location when real coordinates are provided.
    // Ignore 0,0 which older clients sent when going offline — that would
    // wipe the last known location.
    if (lat !== undefined && lng !== undefined && !(lat === 0 && lng === 0)) {
      update.currentLocation = {
        type: 'Point',
        coordinates: [lng, lat], // GeoJSON: [longitude, latitude]
      };
    }

    // Only change online status when it is explicitly sent.
    if (isOnline !== undefined) {
      update.isOnline = isOnline;
      update.isAvailable = isOnline;
    }

    if (Object.keys(update).length === 0) {
      return successResponse({}, 'Nothing to update');
    }

    await Rider.findOneAndUpdate(
      { userId: auth.userId },
      { $set: update }
    );

    return successResponse({}, 'Location updated');
  } catch (error) {
    console.error('Update location error:', error);
    return errorResponse('Failed to update location', 500);
  }
}
