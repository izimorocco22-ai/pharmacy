'use client';

import { useState, useEffect } from 'react';

interface Overview {
  totalOrders: number;
  totalPatients: number;
  totalPharmacies: number;
  totalRiders: number;
  activeOrders: number;
  completedOrders: number;
  cancelledOrders: number;
  totalRevenue: number;
  thisMonthRevenue: number;
  thisMonthOrders: number;
  revenueGrowth: number;
  ordersGrowth: number;
  avgOrderValue: number;
  completionRate: number;
}

const cards = (o: Overview) => [
  {
    title: 'Total Revenue',
    value: `${o.totalRevenue.toLocaleString()} MRO`,
    sub: `This month: ${o.thisMonthRevenue.toLocaleString()} MRO`,
    growth: o.revenueGrowth,
    icon: (
      <svg className="w-6 h-6" fill="none" stroke="currentColor" viewBox="0 0 24 24">
        <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M12 8c-1.657 0-3 .895-3 2s1.343 2 3 2 3 .895 3 2-1.343 2-3 2m0-8c1.11 0 2.08.402 2.599 1M12 8V7m0 1v8m0 0v1m0-1c-1.11 0-2.08-.402-2.599-1M21 12a9 9 0 11-18 0 9 9 0 0118 0z" />
      </svg>
    ),
    iconBg: 'bg-emerald-50',
    iconColor: 'text-emerald-600',
    border: 'border-l-emerald-500',
  },
  {
    title: 'Total Orders',
    value: o.totalOrders.toLocaleString(),
    sub: `This month: ${o.thisMonthOrders}`,
    growth: o.ordersGrowth,
    icon: (
      <svg className="w-6 h-6" fill="none" stroke="currentColor" viewBox="0 0 24 24">
        <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M16 11V7a4 4 0 00-8 0v4M5 9h14l1 12H4L5 9z" />
      </svg>
    ),
    iconBg: 'bg-blue-50',
    iconColor: 'text-blue-600',
    border: 'border-l-blue-500',
  },
  {
    title: 'Active Orders',
    value: o.activeOrders.toLocaleString(),
    sub: 'In progress right now',
    growth: null,
    icon: (
      <svg className="w-6 h-6" fill="none" stroke="currentColor" viewBox="0 0 24 24">
        <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M13 10V3L4 14h7v7l9-11h-7z" />
      </svg>
    ),
    iconBg: 'bg-orange-50',
    iconColor: 'text-orange-500',
    border: 'border-l-orange-500',
  },
  {
    title: 'Completion Rate',
    value: `${o.completionRate}%`,
    sub: `${o.completedOrders} delivered`,
    growth: null,
    icon: (
      <svg className="w-6 h-6" fill="none" stroke="currentColor" viewBox="0 0 24 24">
        <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M9 12l2 2 4-4m6 2a9 9 0 11-18 0 9 9 0 0118 0z" />
      </svg>
    ),
    iconBg: 'bg-green-50',
    iconColor: 'text-green-600',
    border: 'border-l-green-500',
  },
  {
    title: 'Total Patients',
    value: o.totalPatients.toLocaleString(),
    sub: 'Registered users',
    growth: null,
    icon: (
      <svg className="w-6 h-6" fill="none" stroke="currentColor" viewBox="0 0 24 24">
        <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M17 20h5v-2a3 3 0 00-5.356-1.857M17 20H7m10 0v-2c0-.656-.126-1.283-.356-1.857M7 20H2v-2a3 3 0 015.356-1.857M7 20v-2c0-.656.126-1.283.356-1.857m0 0a5.002 5.002 0 019.288 0M15 7a3 3 0 11-6 0 3 3 0 016 0z" />
      </svg>
    ),
    iconBg: 'bg-purple-50',
    iconColor: 'text-purple-600',
    border: 'border-l-purple-500',
  },
  {
    title: 'Pharmacies',
    value: o.totalPharmacies.toLocaleString(),
    sub: 'Approved & active',
    growth: null,
    icon: (
      <svg className="w-6 h-6" fill="none" stroke="currentColor" viewBox="0 0 24 24">
        <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M19 21V5a2 2 0 00-2-2H7a2 2 0 00-2 2v16m14 0h2m-2 0h-5m-9 0H3m2 0h5M9 7h1m-1 4h1m4-4h1m-1 4h1m-5 10v-5a1 1 0 011-1h2a1 1 0 011 1v5m-4 0h4" />
      </svg>
    ),
    iconBg: 'bg-cyan-50',
    iconColor: 'text-cyan-600',
    border: 'border-l-cyan-500',
  },
  {
    title: 'Active Riders',
    value: o.totalRiders.toLocaleString(),
    sub: 'Approved riders',
    growth: null,
    icon: (
      <svg className="w-6 h-6" fill="none" stroke="currentColor" viewBox="0 0 24 24">
        <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M12 4.354a4 4 0 110 5.292M15 21H3v-1a6 6 0 0112 0v1zm0 0h6v-1a6 6 0 00-9-5.197M13 7a4 4 0 11-8 0 4 4 0 018 0z" />
      </svg>
    ),
    iconBg: 'bg-indigo-50',
    iconColor: 'text-indigo-600',
    border: 'border-l-indigo-500',
  },
  {
    title: 'Avg Order Value',
    value: `${o.avgOrderValue} MRO`,
    sub: `${o.cancelledOrders} cancelled`,
    growth: null,
    icon: (
      <svg className="w-6 h-6" fill="none" stroke="currentColor" viewBox="0 0 24 24">
        <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M9 19v-6a2 2 0 00-2-2H5a2 2 0 00-2 2v6a2 2 0 002 2h2a2 2 0 002-2zm0 0V9a2 2 0 012-2h2a2 2 0 012 2v10m-6 0a2 2 0 002 2h2a2 2 0 002-2m0 0V5a2 2 0 012-2h2a2 2 0 012 2v14a2 2 0 01-2 2h-2a2 2 0 01-2-2z" />
      </svg>
    ),
    iconBg: 'bg-rose-50',
    iconColor: 'text-rose-500',
    border: 'border-l-rose-500',
  },
];

export default function DashboardStats() {
  const [overview, setOverview] = useState<Overview | null>(null);
  const [loading, setLoading] = useState(true);

  useEffect(() => {
    fetch('/api/analytics')
      .then(r => r.json())
      .then(d => { if (d.success) setOverview(d.data.overview); })
      .catch(console.error)
      .finally(() => setLoading(false));
  }, []);

  if (loading || !overview) {
    return (
      <div className="grid grid-cols-2 md:grid-cols-4 gap-4">
        {Array.from({ length: 8 }).map((_, i) => (
          <div key={i} className="bg-white rounded-xl border border-gray-200 p-5 animate-pulse">
            <div className="h-3 bg-gray-200 rounded w-2/3 mb-3" />
            <div className="h-7 bg-gray-200 rounded w-1/2 mb-2" />
            <div className="h-3 bg-gray-200 rounded w-3/4" />
          </div>
        ))}
      </div>
    );
  }

  return (
    <div className="grid grid-cols-2 md:grid-cols-4 gap-4">
      {cards(overview).map((card) => (
        <div key={card.title} className={`bg-white rounded-xl border border-gray-200 border-l-4 ${card.border} p-5`}>
          <div className="flex items-start justify-between">
            <div className="min-w-0 flex-1">
              <p className="text-xs font-medium text-gray-500 uppercase tracking-wide mb-1">{card.title}</p>
              <p className="text-2xl font-bold text-gray-900 truncate">{card.value}</p>
              <div className="flex items-center gap-1.5 mt-1.5">
                {card.growth !== null ? (
                  <span className={`text-xs font-semibold flex items-center gap-0.5 ${card.growth >= 0 ? 'text-emerald-600' : 'text-red-500'}`}>
                    {card.growth >= 0 ? (
                      <svg className="w-3 h-3" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                        <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={3} d="M5 10l7-7m0 0l7 7m-7-7v18" />
                      </svg>
                    ) : (
                      <svg className="w-3 h-3" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                        <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={3} d="M19 14l-7 7m0 0l-7-7m7 7V3" />
                      </svg>
                    )}
                    {Math.abs(card.growth)}% vs last month
                  </span>
                ) : (
                  <span className="text-xs text-gray-400">{card.sub}</span>
                )}
              </div>
              {card.growth !== null && (
                <p className="text-xs text-gray-400 mt-0.5">{card.sub}</p>
              )}
            </div>
            <div className={`${card.iconBg} ${card.iconColor} w-11 h-11 rounded-xl flex items-center justify-center flex-shrink-0 ml-3`}>
              {card.icon}
            </div>
          </div>
        </div>
      ))}
    </div>
  );
}
