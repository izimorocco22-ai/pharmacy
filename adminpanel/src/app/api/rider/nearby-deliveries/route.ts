import { NextRequest } from 'next/server';
import connectDB from '@/lib/mongodb';
import Order from '@/models/Order';
import Rider from '@/models/Rider';
import Pharmacy from '@/models/Pharmacy';
import Patient from '@/models/Patient';
import User from '@/models/User';
import { authenticateRequest } from '@/lib/auth';
import { successResponse, errorResponse, unauthorizedResponse } from '@/lib/response';

export const dynamic = 'force-dynamic';

export async function GET(request: NextRequest) {
  try {
    const auth = await authenticateRequest(request);
    if (!auth || auth.role !== 'rider') return unauthorizedResponse();

    await connectDB();

    const rider = await Rider.findOne({ userId: auth.userId });
    if (!rider) return errorResponse('Rider profile not found', 404);

    // Only return orders if rider is online
    if (!rider.isOnline) {
      return successResponse({ deliveries: [] });
    }

    // Fetch unassigned confirmed/ready orders created in last 24 hours
    const since = new Date(Date.now() - 24 * 60 * 60 * 1000);
    const orders = await Order.find({
      status: { $in: ['confirmed', 'preparing', 'ready'] },
      riderId: { $in: [null, undefined] },
      createdAt: { $gte: since },
    })
      .sort({ createdAt: -1 })
      .limit(50)
      .lean() as any[];

    const riderHasLocation =
      rider.currentLocation?.coordinates?.length === 2 &&
      (rider.currentLocation.coordinates[0] !== 0 || rider.currentLocation.coordinates[1] !== 0);

    const result = await Promise.all(orders.map(async (order: any) => {
      let distanceKm: number | null = null;

      if (riderHasLocation) {
        const pharmCoords = order.pharmacyAddress?.location?.coordinates;
        if (pharmCoords?.length === 2 && pharmCoords[0] !== 0 && pharmCoords[1] !== 0) {
          distanceKm = calcDistance(
            rider.currentLocation.coordinates[1],
            rider.currentLocation.coordinates[0],
            pharmCoords[1],
            pharmCoords[0]
          );
          // Strictly filter: only show orders within 20km of rider
          if (distanceKm > 20) return null;
        } else {
          // Rider has location but pharmacy has no coords — skip, can't verify range
          return null;
        }
      }

      // Fetch phone numbers
      let pharmacyPhone = '';
      let patientPhone = '';
      let pharmacyName = '';
      try {
        const pharmacy = await Pharmacy.findById(order.pharmacyId).lean() as any;
        if (pharmacy) {
          pharmacyName = pharmacy.pharmacyName || '';
          const pharmUser = await User.findById(pharmacy.userId).select('phone').lean() as any;
          pharmacyPhone = pharmUser?.phone || '';
        }
      } catch (_) {}
      try {
        const patient = await Patient.findById(order.patientId).lean() as any;
        if (patient) {
          const patUser = await User.findById(patient.userId).select('phone').lean() as any;
          patientPhone = patUser?.phone || '';
        }
      } catch (_) {}

      return {
        orderId: order._id,
        orderNumber: order.orderNumber,
        pickupAddress: order.pharmacyAddress?.address || '',
        deliveryAddress: order.deliveryAddress?.address || '',
        pharmacyCoords: order.pharmacyAddress?.location?.coordinates || null,
        deliveryCoords: order.deliveryAddress?.location?.coordinates || null,
        distance: distanceKm !== null ? Math.round(distanceKm * 10) / 10 : null,
        subtotal: order.subtotal || 0,
        commissionAmount: order.commissionAmount || 0,
        deliveryFee: order.deliveryFee || 0,
        totalAmount: order.totalAmount || 0,
        paymentMethod: order.paymentMethod || 'cash',
        status: order.status,
        pharmacyPhone,
        pharmacyName,
        patientPhone,
        createdAt: order.createdAt,
      };
    }));

    return successResponse({ deliveries: result.filter(Boolean) });
  } catch (error: any) {
    console.error('Get nearby deliveries error:', error);
    return errorResponse('Failed to fetch deliveries', 500);
  }
}

function calcDistance(lat1: number, lon1: number, lat2: number, lon2: number): number {
  const R = 6371;
  const dLat = toRad(lat2 - lat1);
  const dLon = toRad(lon2 - lon1);
  const a =
    Math.sin(dLat / 2) * Math.sin(dLat / 2) +
    Math.cos(toRad(lat1)) * Math.cos(toRad(lat2)) *
    Math.sin(dLon / 2) * Math.sin(dLon / 2);
  return R * 2 * Math.atan2(Math.sqrt(a), Math.sqrt(1 - a));
}

function toRad(v: number) {
  return (v * Math.PI) / 180;
}
