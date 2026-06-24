'use client';

import { useState, useEffect } from 'react';
import Sidebar from '@/components/admin/Sidebar';

interface Overview {
  totalOrders: number; totalPatients: number; totalPharmacies: number; totalRiders: number;
  totalPrescriptions: number; activeOrders: number; completedOrders: number; cancelledOrders: number;
  totalQuotes: number; totalRevenue: number; thisMonthRevenue: number; lastMonthRevenue: number;
  revenueGrowth: number; ordersGrowth: number; thisMonthOrders: number; lastMonthOrders: number;
  avgOrderValue: number; completionRate: number;
}

interface DailyStat { _id: string; orders: number; revenue: number; }
interface StatusStat { _id: string; count: number; }
interface TopPharmacy { name: string; orders: number; revenue: number; }
interface TopRider { name: string; deliveries: number; earnings: number; }

interface Analytics {
  overview: Overview;
  charts: { dailyStats: DailyStat[]; last30Stats: DailyStat[]; ordersByStatus: StatusStat[]; prescriptionsByStatus: StatusStat[] };
  topPerformers: { pharmacies: TopPharmacy[]; riders: TopRider[] };
}

export default function AnalyticsPage() {
  const [sidebarOpen, setSidebarOpen] = useState(true);
  const [data, setData] = useState<Analytics | null>(null);
  const [loading, setLoading] = useState(true);
  const [lastUpdated, setLastUpdated] = useState<Date | null>(null);

  useEffect(() => { fetchAnalytics(); }, []);

  const fetchAnalytics = async () => {
    setLoading(true);
    try {
      const res = await fetch('/api/analytics', { credentials: 'include' });
      const json = await res.json() as any;
      if (json.success) { setData(json.data); setLastUpdated(new Date()); }
    } catch (e) { console.error(e); }
    finally { setLoading(false); }
  };

  const o = data?.overview;
  const growth = (v: number) => v > 0 ? `↑ ${v}%` : v < 0 ? `↓ ${Math.abs(v)}%` : '→ 0%';
  const growthColor = (v: number) => v > 0 ? 'text-green-600' : v < 0 ? 'text-red-500' : 'text-gray-500';

  const statusColors: Record<string, string> = {
    delivered: 'bg-green-500', confirmed: 'bg-purple-500', preparing: 'bg-yellow-500',
    ready: 'bg-lime-500', assigned: 'bg-indigo-500', picked_up: 'bg-cyan-500',
    in_transit: 'bg-blue-500', cancelled: 'bg-red-500', pending: 'bg-orange-500',
  };

  const maxBar = (arr: DailyStat[], key: 'orders' | 'revenue') =>
    Math.max(...arr.map(d => d[key]), 1);

  return (
    <div className="flex h-screen bg-gray-50">
      <Sidebar isOpen={sidebarOpen} />
      <div className="flex-1 flex flex-col overflow-hidden">
        <header className="bg-white shadow-sm">
          <div className="flex items-center justify-between px-6 py-4">
            <div className="flex items-center gap-4">
              <button onClick={() => setSidebarOpen(!sidebarOpen)} className="text-gray-500 hover:text-gray-700">
                <svg className="w-6 h-6" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                  <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M4 6h16M4 12h16M4 18h16" />
                </svg>
              </button>
              <div>
                <h1 className="text-2xl font-semibold text-gray-800">Analytics Dashboard</h1>
                {lastUpdated && <p className="text-xs text-gray-400">Last updated: {lastUpdated.toLocaleTimeString()}</p>}
              </div>
            </div>
            <button onClick={fetchAnalytics} disabled={loading}
              className="flex items-center gap-2 px-4 py-2 bg-green-500 text-white rounded-lg hover:bg-green-600 disabled:opacity-50 text-sm font-medium">
              <svg className={`w-4 h-4 ${loading ? 'animate-spin' : ''}`} fill="none" stroke="currentColor" viewBox="0 0 24 24">
                <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M4 4v5h.582m15.356 2A8.001 8.001 0 004.582 9m0 0H9m11 11v-5h-.581m0 0a8.003 8.003 0 01-15.357-2m15.357 2H15" />
              </svg>
              {loading ? 'Loading...' : 'Refresh'}
            </button>
          </div>
        </header>

        <main className="flex-1 overflow-y-auto p-6 space-y-6">
          {loading && !data ? (
            <div className="flex items-center justify-center h-64">
              <div className="text-center">
                <div className="animate-spin w-10 h-10 border-4 border-green-500 border-t-transparent rounded-full mx-auto mb-3" />
                <p className="text-gray-500">Loading analytics...</p>
              </div>
            </div>
          ) : (
            <>
              {/* KPI Cards */}
              <div className="grid grid-cols-2 md:grid-cols-4 gap-4">
                {[
                  { label: 'Total Revenue', value: `${(o?.totalRevenue || 0).toLocaleString()} MRO`, sub: `This month: ${(o?.thisMonthRevenue || 0).toLocaleString()} MRO`, growth: o?.revenueGrowth || 0, emoji: '💰', color: 'bg-green-500' },
                  { label: 'Total Orders', value: `${o?.totalOrders || 0}`, sub: `This month: ${o?.thisMonthOrders || 0}`, growth: o?.ordersGrowth || 0, emoji: '📦', color: 'bg-blue-500' },
                  { label: 'Avg Order Value', value: `${o?.avgOrderValue || 0} MRO`, sub: `${o?.completedOrders || 0} delivered`, growth: 0, emoji: '📊', color: 'bg-purple-500' },
                  { label: 'Completion Rate', value: `${o?.completionRate || 0}%`, sub: `${o?.cancelledOrders || 0} cancelled`, growth: 0, emoji: '✅', color: 'bg-yellow-500' },
                ].map(card => (
                  <div key={card.label} className="bg-white rounded-xl shadow-sm p-5 border border-gray-100">
                    <div className="flex items-start justify-between">
                      <div className="flex-1 min-w-0">
                        <p className="text-sm text-gray-500 mb-1">{card.label}</p>
                        <p className="text-xl font-bold text-gray-800 truncate">{card.value}</p>
                        <p className="text-xs text-gray-400 mt-0.5 truncate">{card.sub}</p>
                        {card.growth !== 0 && (
                          <p className={`text-xs mt-1 font-medium ${growthColor(card.growth)}`}>
                            {growth(card.growth)} vs last month
                          </p>
                        )}
                      </div>
                      <div className={`${card.color} w-10 h-10 rounded-full flex items-center justify-center text-lg flex-shrink-0 ml-2`}>
                        {card.emoji}
                      </div>
                    </div>
                  </div>
                ))}
              </div>

              {/* Platform Stats */}
              <div className="grid grid-cols-2 md:grid-cols-5 gap-4">
                {[
                  { label: 'Patients', value: o?.totalPatients || 0, emoji: '👥', color: 'text-blue-600 bg-blue-50' },
                  { label: 'Pharmacies', value: o?.totalPharmacies || 0, emoji: '🏥', color: 'text-purple-600 bg-purple-50' },
                  { label: 'Riders', value: o?.totalRiders || 0, emoji: '🏍️', color: 'text-green-600 bg-green-50' },
                  { label: 'Prescriptions', value: o?.totalPrescriptions || 0, emoji: '📋', color: 'text-orange-600 bg-orange-50' },
                  { label: 'Active Orders', value: o?.activeOrders || 0, emoji: '⚡', color: 'text-red-600 bg-red-50' },
                ].map(s => (
                  <div key={s.label} className={`rounded-xl p-4 ${s.color} border border-opacity-20`}>
                    <div className="flex items-center gap-3">
                      <span className="text-2xl">{s.emoji}</span>
                      <div>
                        <p className="text-2xl font-bold">{s.value}</p>
                        <p className="text-xs opacity-70">{s.label}</p>
                      </div>
                    </div>
                  </div>
                ))}
              </div>

              {/* Charts Row */}
              <div className="grid grid-cols-1 lg:grid-cols-2 gap-6">
                {/* Last 30 days orders bar chart */}
                <div className="bg-white rounded-xl shadow-sm p-6 border border-gray-100">
                  <h3 className="text-base font-semibold text-gray-800 mb-4">Orders — Last 30 Days</h3>
                  {data?.charts.last30Stats.length === 0 ? (
                    <p className="text-gray-400 text-sm text-center py-8">No data yet</p>
                  ) : (
                    <div className="flex items-end gap-1" style={{ height: '128px' }}>
                      {data?.charts.last30Stats.map((d, i) => {
                        const pct = (d.orders / maxBar(data.charts.last30Stats, 'orders')) * 100;
                        return (
                          <div key={i} className="flex-1 group relative" style={{ height: `${Math.max(pct, 4)}%` }}>
                            <div className="absolute -top-7 left-1/2 -translate-x-1/2 bg-gray-800 text-white text-xs px-1.5 py-0.5 rounded opacity-0 group-hover:opacity-100 whitespace-nowrap z-10">
                              {d._id}: {d.orders}
                            </div>
                            <div className="w-full h-full bg-green-500 rounded-t" />
                          </div>
                        );
                      })}
                    </div>
                  )}
                  <p className="text-xs text-gray-400 mt-2 text-center">Each bar = 1 day</p>
                </div>

                {/* Order status breakdown */}
                <div className="bg-white rounded-xl shadow-sm p-6 border border-gray-100">
                  <h3 className="text-base font-semibold text-gray-800 mb-4">Order Status Breakdown</h3>
                  <div className="space-y-3">
                    {data?.charts.ordersByStatus.map(s => {
                      const pct = o?.totalOrders ? Math.round((s.count / o.totalOrders) * 100) : 0;
                      const color = statusColors[s._id] || 'bg-gray-400';
                      return (
                        <div key={s._id}>
                          <div className="flex justify-between text-sm mb-1">
                            <span className="text-gray-600 capitalize">{s._id.replace(/_/g, ' ')}</span>
                            <span className="font-medium text-gray-800">{s.count} ({pct}%)</span>
                          </div>
                          <div className="w-full bg-gray-100 rounded-full h-2">
                            <div className={`${color} h-2 rounded-full transition-all`} style={{ width: `${pct}%` }} />
                          </div>
                        </div>
                      );
                    })}
                  </div>
                </div>
              </div>

              {/* Revenue chart */}
              <div className="bg-white rounded-xl shadow-sm p-6 border border-gray-100">
                <div className="flex items-center justify-between mb-4">
                  <h3 className="text-base font-semibold text-gray-800">Revenue — Last 30 Days</h3>
                  <span className="text-sm text-gray-500">Total: {(o?.totalRevenue || 0).toLocaleString()} MRO</span>
                </div>
                {data?.charts.last30Stats.length === 0 ? (
                  <p className="text-gray-400 text-sm text-center py-8">No revenue data yet</p>
                ) : (
                  <div className="flex items-end gap-1" style={{ height: '96px' }}>
                    {data?.charts.last30Stats.map((d, i) => {
                      const pct = (d.revenue / maxBar(data.charts.last30Stats, 'revenue')) * 100;
                      return (
                        <div key={i} className="flex-1 group relative" style={{ height: `${Math.max(pct, 4)}%` }}>
                          <div className="absolute -top-8 left-1/2 -translate-x-1/2 bg-gray-800 text-white text-xs px-1.5 py-0.5 rounded opacity-0 group-hover:opacity-100 whitespace-nowrap z-10">
                            {d._id}: {d.revenue.toLocaleString()} MRO
                          </div>
                          <div className="w-full h-full bg-blue-400 rounded-t" />
                        </div>
                      );
                    })}
                  </div>
                )}
              </div>

              {/* Top Performers */}
              <div className="grid grid-cols-1 lg:grid-cols-2 gap-6">
                {/* Top Pharmacies */}
                <div className="bg-white rounded-xl shadow-sm border border-gray-100">
                  <div className="px-6 py-4 border-b border-gray-100">
                    <h3 className="text-base font-semibold text-gray-800">🏥 Top Pharmacies</h3>
                  </div>
                  {data?.topPerformers.pharmacies.length === 0 ? (
                    <p className="text-gray-400 text-sm text-center py-8">No data yet</p>
                  ) : (
                    <table className="w-full">
                      <thead>
                        <tr className="border-b border-gray-100 bg-gray-50">
                          <th className="text-left py-3 px-5 text-xs font-semibold text-gray-500">#</th>
                          <th className="text-left py-3 px-5 text-xs font-semibold text-gray-500">Pharmacy</th>
                          <th className="text-left py-3 px-5 text-xs font-semibold text-gray-500">Orders</th>
                          <th className="text-left py-3 px-5 text-xs font-semibold text-gray-500">Revenue</th>
                        </tr>
                      </thead>
                      <tbody>
                        {data?.topPerformers.pharmacies.map((p, i) => (
                          <tr key={i} className="border-b border-gray-50 hover:bg-gray-50">
                            <td className="py-3 px-5 text-sm font-bold text-gray-400">#{i + 1}</td>
                            <td className="py-3 px-5">
                              <div className="flex items-center gap-2">
                                <div className="w-8 h-8 rounded-full bg-purple-100 flex items-center justify-center text-purple-600 font-bold text-sm">
                                  {p.name.charAt(0)}
                                </div>
                                <span className="text-sm font-medium text-gray-800">{p.name}</span>
                              </div>
                            </td>
                            <td className="py-3 px-5 text-sm font-medium text-gray-800">{p.orders}</td>
                            <td className="py-3 px-5 text-sm font-medium text-green-600">{p.revenue.toLocaleString()} MRO</td>
                          </tr>
                        ))}
                      </tbody>
                    </table>
                  )}
                </div>

                {/* Top Riders */}
                <div className="bg-white rounded-xl shadow-sm border border-gray-100">
                  <div className="px-6 py-4 border-b border-gray-100">
                    <h3 className="text-base font-semibold text-gray-800">🏍️ Top Riders</h3>
                  </div>
                  {data?.topPerformers.riders.length === 0 ? (
                    <p className="text-gray-400 text-sm text-center py-8">No data yet</p>
                  ) : (
                    <table className="w-full">
                      <thead>
                        <tr className="border-b border-gray-100 bg-gray-50">
                          <th className="text-left py-3 px-5 text-xs font-semibold text-gray-500">#</th>
                          <th className="text-left py-3 px-5 text-xs font-semibold text-gray-500">Rider</th>
                          <th className="text-left py-3 px-5 text-xs font-semibold text-gray-500">Deliveries</th>
                          <th className="text-left py-3 px-5 text-xs font-semibold text-gray-500">Earnings</th>
                        </tr>
                      </thead>
                      <tbody>
                        {data?.topPerformers.riders.map((r, i) => (
                          <tr key={i} className="border-b border-gray-50 hover:bg-gray-50">
                            <td className="py-3 px-5 text-sm font-bold text-gray-400">#{i + 1}</td>
                            <td className="py-3 px-5">
                              <div className="flex items-center gap-2">
                                <div className="w-8 h-8 rounded-full bg-green-100 flex items-center justify-center text-green-600 font-bold text-sm">
                                  {r.name.charAt(0)}
                                </div>
                                <span className="text-sm font-medium text-gray-800">{r.name}</span>
                              </div>
                            </td>
                            <td className="py-3 px-5 text-sm font-medium text-gray-800">{r.deliveries}</td>
                            <td className="py-3 px-5 text-sm font-medium text-green-600">{r.earnings.toLocaleString()} MRO</td>
                          </tr>
                        ))}
                      </tbody>
                    </table>
                  )}
                </div>
              </div>

              {/* Prescription status */}
              <div className="bg-white rounded-xl shadow-sm p-6 border border-gray-100">
                <h3 className="text-base font-semibold text-gray-800 mb-4">📋 Prescription Status Breakdown</h3>
                <div className="grid grid-cols-2 md:grid-cols-5 gap-3">
                  {data?.charts.prescriptionsByStatus.map(s => (
                    <div key={s._id} className="text-center bg-gray-50 rounded-xl p-4">
                      <p className="text-2xl font-bold text-gray-800">{s.count}</p>
                      <p className="text-xs text-gray-500 capitalize mt-1">{s._id}</p>
                    </div>
                  ))}
                </div>
              </div>
            </>
          )}
        </main>
      </div>
    </div>
  );
}
