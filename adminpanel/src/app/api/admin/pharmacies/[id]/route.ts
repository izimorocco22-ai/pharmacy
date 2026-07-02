import { NextRequest } from 'next/server';
import { connectDB } from '@/lib/mongodb';
import User from '@/models/User';
import Pharmacy from '@/models/Pharmacy';
import Order from '@/models/Order';
import Quote from '@/models/Quote';
import Prescription from '@/models/Prescription';
import PharmacySettlement from '@/models/PharmacySettlement';
import { successResponse, errorResponse } from '@/lib/response';

export const dynamic = 'force-dynamic';

export async function GET(request: NextRequest, { params }: { params: { id: string } }) {
  try {
    await connectDB();

    // id can be userId or pharmacyId
    const user = await User.findById(params.id).select('-password').lean() as any;
    if (!user) return errorResponse('Pharmacy not found', 404);

    const pharmacy = await Pharmacy.findOne({ userId: user._id }).lean() as any;
    if (!pharmacy) return errorResponse('Pharmacy profile not found', 404);

    // Orders
    const orders = await Order.find({ pharmacyId: pharmacy._id })
      .sort({ createdAt: -1 })
      .lean() as any[];

    // Revenue stats
    const totalRevenue = orders
      .filter((o: any) => o.status === 'delivered')
      .reduce((sum: number, o: any) => sum + (o.totalAmount || 0), 0);

    const monthlyRevenue = await Order.aggregate([
      { $match: { pharmacyId: pharmacy._id, status: 'delivered' } },
      {
        $group: {
          _id: { $dateToString: { format: '%Y-%m', date: '$createdAt' } },
          revenue: { $sum: '$totalAmount' },
          count: { $sum: 1 },
        },
      },
      { $sort: { _id: -1 } },
      { $limit: 6 },
    ]);

    // Earnings & commission per month (delivered orders only).
    // - subtotal      = what the pharmacy earns (medicine value it keeps)
    // - commission    = platform's cut => what the pharmacy owes us
    // - totalAmount   = full amount collected from the patient
    const earningsByMonth = await Order.aggregate([
      { $match: { pharmacyId: pharmacy._id, status: 'delivered' } },
      {
        $group: {
          _id: { $dateToString: { format: '%Y-%m', date: '$createdAt' } },
          orders: { $sum: 1 },
          subtotal: { $sum: '$subtotal' },
          commission: { $sum: '$commissionAmount' },
          deliveryFee: { $sum: '$deliveryFee' },
          totalAmount: { $sum: '$totalAmount' },
        },
      },
      { $sort: { _id: -1 } },
    ]);

    const round = (n: number) => Math.round((n || 0) * 100) / 100;
    const monthlyEarnings = earningsByMonth.map((m: any) => ({
      month: m._id,
      orders: m.orders,
      subtotal: round(m.subtotal),
      commission: round(m.commission),
      deliveryFee: round(m.deliveryFee),
      totalAmount: round(m.totalAmount),
    }));
    const allTimeEarnings = monthlyEarnings.reduce(
      (acc: any, m: any) => ({
        orders: acc.orders + m.orders,
        subtotal: round(acc.subtotal + m.subtotal),
        commission: round(acc.commission + m.commission),
        deliveryFee: round(acc.deliveryFee + m.deliveryFee),
        totalAmount: round(acc.totalAmount + m.totalAmount),
      }),
      { orders: 0, subtotal: 0, commission: 0, deliveryFee: 0, totalAmount: 0 },
    );

    // Settlements (payments/adjustments) recorded against commission dues.
    const settlements = await PharmacySettlement.find({ pharmacyId: pharmacy._id })
      .sort({ createdAt: -1 })
      .lean() as any[];
    const totalPaid = round(
      settlements.reduce((s: number, x: any) => s + (x.amount || 0), 0),
    );
    const outstandingDue = round(allTimeEarnings.commission - totalPaid);

    // Order status breakdown
    const statusBreakdown = await Order.aggregate([
      { $match: { pharmacyId: pharmacy._id } },
      { $group: { _id: '$status', count: { $sum: 1 } } },
    ]);

    // Prescriptions assigned to this pharmacy
    const prescriptions = await Prescription.find({
      nearbyPharmacies: pharmacy._id,
    })
      .sort({ createdAt: -1 })
      .limit(20)
      .lean() as any[];

    // Quotes sent by this pharmacy
    const quotes = await Quote.find({ pharmacyId: pharmacy._id })
      .sort({ createdAt: -1 })
      .limit(20)
      .lean() as any[];

    const acceptedQuotes = quotes.filter((q: any) => q.status === 'accepted').length;
    const acceptanceRate = quotes.length > 0
      ? Math.round((acceptedQuotes / quotes.length) * 100)
      : 0;

    return successResponse({
      pharmacy: {
        id: user._id,
        pharmacyId: pharmacy._id,
        name: pharmacy.pharmacyName,
        email: user.email,
        phone: user.phone,
        licenseNumber: pharmacy.licenseNumber,
        address: pharmacy.address,
        coordinates: pharmacy.location?.coordinates,
        isActive: user.isActive,
        isVerified: user.isVerified,
        approvalStatus: pharmacy.approvalStatus,
        rating: pharmacy.rating,
        isOpen: pharmacy.isOpen,
        createdAt: user.createdAt,
      },
      stats: {
        totalOrders: orders.length,
        deliveredOrders: orders.filter((o: any) => o.status === 'delivered').length,
        pendingOrders: orders.filter((o: any) => ['confirmed', 'preparing', 'picked_up', 'in_transit'].includes(o.status)).length,
        cancelledOrders: orders.filter((o: any) => o.status === 'cancelled').length,
        totalRevenue: Math.round(totalRevenue * 100) / 100,
        totalPrescriptions: prescriptions.length,
        totalQuotes: quotes.length,
        acceptedQuotes,
        acceptanceRate,
      },
      monthlyRevenue,
      earnings: {
        allTime: allTimeEarnings,
        monthly: monthlyEarnings,
      },
      settlement: {
        totalCommission: allTimeEarnings.commission,
        totalPaid,
        due: outstandingDue,
      },
      settlements: settlements.map((s: any) => ({
        id: s._id,
        amount: s.amount,
        type: s.type,
        note: s.note,
        month: s.month,
        createdAt: s.createdAt,
      })),
      statusBreakdown,
      recentOrders: orders.slice(0, 10).map((o: any) => ({
        id: o._id,
        orderNumber: o.orderNumber,
        totalAmount: o.totalAmount,
        status: o.status,
        paymentMethod: o.paymentMethod,
        createdAt: o.createdAt,
      })),
    });
  } catch (error) {
    console.error('Pharmacy detail error:', error);
    return errorResponse('Failed to fetch pharmacy details', 500);
  }
}
