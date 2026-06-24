'use client';

import { useState, useEffect } from 'react';
import Link from 'next/link';

interface TopPharmacy { name: string; orders: number; revenue: number; }
interface TopRider { name: string; deliveries: number; earnings: number; }
interface PrescStat { _id: string; count: number; }

const QUICK_LINKS = [
  { label: 'Registration Requests', href: '/admin/registration-requests', icon: (
    <svg className="w-5 h-5" fill="none" stroke="currentColor" viewBox="0 0 24 24">
      <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M9 5H7a2 2 0 00-2 2v12a2 2 0 002 2h10a2 2 0 002-2V7a2 2 0 00-2-2h-2M9 5a2 2 0 002 2h2a2 2 0 002-2M9 5a2 2 0 012-2h2a2 2 0 012 2m-6 9l2 2 4-4" />
    </svg>
  ), color: 'bg-yellow-50 text-yellow-600 border-yellow-200' },
  { label: 'Manage Orders', href: '/admin/orders', icon: (
    <svg className="w-5 h-5" fill="none" stroke="currentColor" viewBox="0 0 24 24">
      <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M16 11V7a4 4 0 00-8 0v4M5 9h14l1 12H4L5 9z" />
    </svg>
  ), color: 'bg-blue-50 text-blue-600 border-blue-200' },
  { label: 'Prescriptions', href: '/admin/prescriptions', icon: (
    <svg className="w-5 h-5" fill="none" stroke="currentColor" viewBox="0 0 24 24">
      <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M9 12h6m-6 4h6m2 5H7a2 2 0 01-2-2V5a2 2 0 012-2h5.586a1 1 0 01.707.293l5.414 5.414a1 1 0 01.293.707V19a2 2 0 01-2 2z" />
    </svg>
  ), color: 'bg-green-50 text-green-600 border-green-200' },
  { label: 'Analytics', href: '/admin/analytics', icon: (
    <svg className="w-5 h-5" fill="none" stroke="currentColor" viewBox="0 0 24 24">
      <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M9 19v-6a2 2 0 00-2-2H5a2 2 0 00-2 2v6a2 2 0 002 2h2a2 2 0 002-2zm0 0V9a2 2 0 012-2h2a2 2 0 012 2v10m-6 0a2 2 0 002 2h2a2 2 0 002-2m0 0V5a2 2 0 012-2h2a2 2 0 012 2v14a2 2 0 01-2 2h-2a2 2 0 01-2-2z" />
    </svg>
  ), color: 'bg-purple-50 text-purple-600 border-purple-200' },
  { label: 'Patients', href: '/admin/patients', icon: (
    <svg className="w-5 h-5" fill="none" stroke="currentColor" viewBox="0 0 24 24">
      <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M17 20h5v-2a3 3 0 00-5.356-1.857M17 20H7m10 0v-2c0-.656-.126-1.283-.356-1.857M7 20H2v-2a3 3 0 015.356-1.857M7 20v-2c0-.656.126-1.283.356-1.857m0 0a5.002 5.002 0 019.288 0M15 7a3 3 0 11-6 0 3 3 0 016 0z" />
    </svg>
  ), color: 'bg-pink-50 text-pink-600 border-pink-200' },
  { label: 'Settings', href: '/admin/settings', icon: (
    <svg className="w-5 h-5" fill="none" stroke="currentColor" viewBox="0 0 24 24">
      <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M10.325 4.317c.426-1.756 2.924-1.756 3.35 0a1.724 1.724 0 002.573 1.066c1.543-.94 3.31.826 2.37 2.37a1.724 1.724 0 001.065 2.572c1.756.426 1.756 2.924 0 3.35a1.724 1.724 0 00-1.066 2.573c.94 1.543-.826 3.31-2.37 2.37a1.724 1.724 0 00-2.572 1.065c-.426 1.756-2.924 1.756-3.35 0a1.724 1.724 0 00-2.573-1.066c-1.543.94-3.31-.826-2.37-2.37a1.724 1.724 0 00-1.065-2.572c-1.756-.426-1.756-2.924 0-3.35a1.724 1.724 0 001.066-2.573c-.94-1.543.826-3.31 2.37-2.37.996.608 2.296.07 2.572-1.065z" />
      <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M15 12a3 3 0 11-6 0 3 3 0 016 0z" />
    </svg>
  ), color: 'bg-gray-50 text-gray-600 border-gray-200' },
];

export default function PlatformOverview() {
  const [pharmacies, setPharmacies] = useState<TopPharmacy[]>([]);
  const [riders, setRiders] = useState<TopRider[]>([]);
  const [prescStats, setPrescStats] = useState<PrescStat[]>([]);
  const [loading, setLoading] = useState(true);

  useEffect(() => {
    fetch('/api/analytics')
      .then(r => r.json())
      .then(d => {
        if (d.success) {
          setPharmacies(d.data.topPerformers.pharmacies || []);
          setRiders(d.data.topPerformers.riders || []);
          setPrescStats(d.data.charts.prescriptionsByStatus || []);
        }
      })
      .catch(console.error)
      .finally(() => setLoading(false));
  }, []);

  const maxPharmacyOrders = Math.max(...pharmacies.map(p => p.orders), 1);
  const maxRiderDeliveries = Math.max(...riders.map(r => r.deliveries), 1);

  return (
    <div className="grid grid-cols-1 lg:grid-cols-3 gap-6">

      {/* Top Pharmacies */}
      <div className="bg-white rounded-xl border border-gray-200 p-6">
        <div className="flex items-center justify-between mb-5">
          <div>
            <h3 className="text-base font-bold text-gray-900">Top Pharmacies</h3>
            <p className="text-xs text-gray-400 mt-0.5">By delivered orders</p>
          </div>
          <Link href="/admin/pharmacies" className="text-xs font-semibold text-green-600 hover:text-green-700">View all →</Link>
        </div>
        {loading ? (
          <div className="space-y-4">
            {[1,2,3].map(i => <div key={i} className="h-10 bg-gray-100 rounded-lg animate-pulse" />)}
          </div>
        ) : pharmacies.length === 0 ? (
          <p className="text-sm text-gray-400 text-center py-6">No data yet</p>
        ) : (
          <div className="space-y-4">
            {pharmacies.map((p, i) => (
              <div key={i}>
                <div className="flex items-center justify-between mb-1.5">
                  <div className="flex items-center gap-2.5">
                    <div className="w-7 h-7 rounded-full bg-purple-100 text-purple-700 flex items-center justify-center font-bold text-xs flex-shrink-0">
                      {p.name.charAt(0).toUpperCase()}
                    </div>
                    <span className="text-sm font-medium text-gray-800 truncate max-w-[120px]">{p.name}</span>
                  </div>
                  <div className="text-right flex-shrink-0">
                    <span className="text-sm font-bold text-gray-900">{p.orders}</span>
                    <span className="text-xs text-gray-400 ml-1">orders</span>
                  </div>
                </div>
                <div className="w-full bg-gray-100 rounded-full h-1.5">
                  <div className="bg-purple-500 h-1.5 rounded-full transition-all" style={{ width: `${(p.orders / maxPharmacyOrders) * 100}%` }} />
                </div>
                <p className="text-xs text-gray-400 mt-1">{p.revenue.toLocaleString()} MRO revenue</p>
              </div>
            ))}
          </div>
        )}
      </div>

      {/* Top Riders */}
      <div className="bg-white rounded-xl border border-gray-200 p-6">
        <div className="flex items-center justify-between mb-5">
          <div>
            <h3 className="text-base font-bold text-gray-900">Top Riders</h3>
            <p className="text-xs text-gray-400 mt-0.5">By deliveries completed</p>
          </div>
          <Link href="/admin/riders" className="text-xs font-semibold text-green-600 hover:text-green-700">View all →</Link>
        </div>
        {loading ? (
          <div className="space-y-4">
            {[1,2,3].map(i => <div key={i} className="h-10 bg-gray-100 rounded-lg animate-pulse" />)}
          </div>
        ) : riders.length === 0 ? (
          <p className="text-sm text-gray-400 text-center py-6">No data yet</p>
        ) : (
          <div className="space-y-4">
            {riders.map((r, i) => (
              <div key={i}>
                <div className="flex items-center justify-between mb-1.5">
                  <div className="flex items-center gap-2.5">
                    <div className="w-7 h-7 rounded-full bg-indigo-100 text-indigo-700 flex items-center justify-center font-bold text-xs flex-shrink-0">
                      {r.name.charAt(0).toUpperCase()}
                    </div>
                    <span className="text-sm font-medium text-gray-800 truncate max-w-[120px]">{r.name}</span>
                  </div>
                  <div className="text-right flex-shrink-0">
                    <span className="text-sm font-bold text-gray-900">{r.deliveries}</span>
                    <span className="text-xs text-gray-400 ml-1">trips</span>
                  </div>
                </div>
                <div className="w-full bg-gray-100 rounded-full h-1.5">
                  <div className="bg-indigo-500 h-1.5 rounded-full transition-all" style={{ width: `${(r.deliveries / maxRiderDeliveries) * 100}%` }} />
                </div>
                <p className="text-xs text-gray-400 mt-1">{r.earnings.toLocaleString()} MRO earned</p>
              </div>
            ))}
          </div>
        )}
      </div>

      {/* Right column: Prescription stats + Quick links */}
      <div className="flex flex-col gap-6">

        {/* Prescription status */}
        <div className="bg-white rounded-xl border border-gray-200 p-6">
          <div className="flex items-center justify-between mb-4">
            <h3 className="text-base font-bold text-gray-900">Prescriptions</h3>
            <Link href="/admin/prescriptions" className="text-xs font-semibold text-green-600 hover:text-green-700">View all →</Link>
          </div>
          {loading ? (
            <div className="grid grid-cols-3 gap-2">
              {[1,2,3].map(i => <div key={i} className="h-14 bg-gray-100 rounded-lg animate-pulse" />)}
            </div>
          ) : prescStats.length === 0 ? (
            <p className="text-sm text-gray-400 text-center py-4">No data yet</p>
          ) : (
            <div className="grid grid-cols-3 gap-2">
              {prescStats.map(s => {
                const colors: Record<string, string> = {
                  pending: 'bg-yellow-50 text-yellow-700',
                  quoted: 'bg-blue-50 text-blue-700',
                  accepted: 'bg-green-50 text-green-700',
                  rejected: 'bg-red-50 text-red-600',
                  expired: 'bg-gray-50 text-gray-500',
                };
                return (
                  <div key={s._id} className={`rounded-lg p-2.5 text-center ${colors[s._id] || 'bg-gray-50 text-gray-600'}`}>
                    <p className="text-xl font-bold">{s.count}</p>
                    <p className="text-xs capitalize mt-0.5 opacity-80">{s._id}</p>
                  </div>
                );
              })}
            </div>
          )}
        </div>

        {/* Quick links */}
        <div className="bg-white rounded-xl border border-gray-200 p-6">
          <h3 className="text-base font-bold text-gray-900 mb-4">Quick Navigation</h3>
          <div className="grid grid-cols-2 gap-2">
            {QUICK_LINKS.map(link => (
              <Link key={link.href} href={link.href}
                className={`flex items-center gap-2.5 px-3 py-2.5 rounded-lg border text-sm font-medium transition-all hover:shadow-sm ${link.color}`}>
                {link.icon}
                <span className="truncate">{link.label}</span>
              </Link>
            ))}
          </div>
        </div>

      </div>
    </div>
  );
}
