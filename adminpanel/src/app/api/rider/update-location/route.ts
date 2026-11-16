import { NextRequest } from 'next/server';
import connectDB from '@/lib/mongodb';
import Rider from '@/models/Rider';
import Order from '@/models/Order';
import { authenticateRequest } from '@/lib/auth';
import { successResponse, errorResponse, unauthorizedResponse } from '@/lib/response';
import { sendNotificationToUser } from '@/services/notification';

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

    const rider = await Rider.findOneAndUpdate(
      { userId: auth.userId },
      { $set: update },
      { new: true }
    );

    // When the rider has just come ONLINE, notify them about unassigned
    // deliveries waiting nearby — so a rider who comes online after an order
    // was placed still gets alerted (the order-time notification only reaches
    // riders who were already online).
    if (isOnline === true && rider) {
      try {
        const since = new Date(Date.now() - 24 * 60 * 60 * 1000);
        const baseFilter: any = {
          status: { $in: ['confirmed', 'preparing', 'ready'] },
          riderId: { $in: [null, undefined] },
          createdAt: { $gte: since },
        };
        let count = 0;
        const coords = rider.currentLocation?.coordinates;
        if (coords && coords.length === 2 && (coords[0] !== 0 || coords[1] !== 0)) {
          // Use $geoWithin/$centerSphere (not $near) — $near is rejected inside
          // the $match that countDocuments runs. Radius is in radians:
          // kilometres / Earth radius (6378.1 km). 20 km radius here.
          count = await Order.countDocuments({
            ...baseFilter,
            'pharmacyAddress.location': {
              $geoWithin: {
                $centerSphere: [coords, 20 / 6378.1],
              },
            },
          });
        } else {
          count = await Order.countDocuments(baseFilter);
        }
        if (count > 0) {
          await sendNotificationToUser(
            auth.userId,
            count === 1 ? 'A delivery is waiting' : `${count} deliveries waiting`,
            count === 1
              ? 'A delivery near you needs a rider. Open the app to accept it.'
              : `${count} deliveries near you need a rider. Open the app to accept.`,
            { type: 'delivery_available' }
          );
        }
      } catch (_) {}
    }

    return successResponse({}, 'Location updated');
  } catch (error) {
    console.error('Update location error:', error);
    return errorResponse('Failed to update location', 500);
  }
}
