'use client';

import { useState, useEffect } from 'react';
import Link from 'next/link';

const STATUS_STYLES: Record<string, string> = {
  delivered: 'bg-emerald-100 text-emerald-700',
  in_transit: 'bg-blue-100 text-blue-700',
  picked_up: 'bg-cyan-100 text-cyan-700',
  preparing: 'bg-yellow-100 text-yellow-700',
  confirmed: 'bg-purple-100 text-purple-700',
  assigned: 'bg-indigo-100 text-indigo-700',
  ready: 'bg-lime-100 text-lime-700',
  cancelled: 'bg-red-100 text-red-600',
  pending: 'bg-orange-100 text-orange-700',
};

function timeAgo(dateStr: string) {
  const diff = Date.now() - new Date(dateStr).getTime();
  const mins = Math.floor(diff / 60000);
  if (mins < 1) return 'just now';
  if (mins < 60) return `${mins}m ago`;
  const hrs = Math.floor(mins / 60);
  if (hrs < 24) return `${hrs}h ago`;
  return `${Math.floor(hrs / 24)}d ago`;
}

export default function RecentOrders() {
  const [orders, setOrders] = useState<any[]>([]);
  const [loading, setLoading] = useState(true);

  useEffect(() => {
    fetch('/api/orders?limit=8')
      .then(r => r.json())
      .then(d => { if (d.success) setOrders(d.data.orders || []); })
      .catch(console.error)
      .finally(() => setLoading(false));
  }, []);

  return (
    <div className="bg-white rounded-xl border border-gray-200 p-6 flex flex-col h-full">
      <div className="flex items-center justify-between mb-5">
        <div>
          <h2 className="text-base font-bold text-gray-900">Recent Orders</h2>
          <p className="text-xs text-gray-400 mt-0.5">Latest activity</p>
        </div>
        <Link href="/admin/orders" className="text-xs font-semibold text-green-600 hover:text-green-700 flex items-center gap-1">
          View all
          <svg className="w-3.5 h-3.5" fill="none" stroke="currentColor" viewBox="0 0 24 24">
            <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2.5} d="M9 5l7 7-7 7" />
          </svg>
        </Link>
      </div>

      {loading ? (
        <div className="space-y-3 flex-1">
          {Array.from({ length: 6 }).map((_, i) => (
            <div key={i} className="flex items-center gap-3 animate-pulse">
              <div className="w-9 h-9 rounded-full bg-gray-200 flex-shrink-0" />
              <div className="flex-1">
                <div className="h-3 bg-gray-200 rounded w-3/4 mb-1.5" />
                <div className="h-2.5 bg-gray-200 rounded w-1/2" />
              </div>
              <div className="h-5 bg-gray-200 rounded-full w-16" />
            </div>
          ))}
        </div>
      ) : orders.length === 0 ? (
        <div className="flex-1 flex items-center justify-center text-gray-400 text-sm">No orders yet</div>
      ) : (
        <div className="space-y-3 flex-1 overflow-y-auto">
          {orders.map((order) => {
            const name = order.patientName || order.patientId?.fullName || 'Patient';
            const initial = name.charAt(0).toUpperCase();
            const statusStyle = STATUS_STYLES[order.status] || 'bg-gray-100 text-gray-600';
            const label = order.status.replace(/_/g, ' ').replace(/\b\w/g, (c: string) => c.toUpperCase());
            return (
              <div key={order._id} className="flex items-center gap-3 py-1">
                <div className="w-9 h-9 rounded-full bg-green-100 text-green-700 flex items-center justify-center font-bold text-sm flex-shrink-0">
                  {initial}
                </div>
                <div className="flex-1 min-w-0">
                  <p className="text-sm font-semibold text-gray-800 truncate">{name}</p>
                  <p className="text-xs text-gray-400 truncate">
                    {order.orderNumber || order._id.slice(-6).toUpperCase()} · {timeAgo(order.createdAt)}
                  </p>
                </div>
                <div className="flex flex-col items-end gap-1 flex-shrink-0">
                  <span className="text-sm font-bold text-gray-800">{order.totalAmount} MRO</span>
                  <span className={`text-xs px-2 py-0.5 rounded-full font-medium ${statusStyle}`}>{label}</span>
                </div>
              </div>
            );
          })}
        </div>
      )}
    </div>
  );
}
