'use client';

import { useState, useEffect } from 'react';
import { useParams, useRouter } from 'next/navigation';
import Sidebar from '@/components/admin/Sidebar';

export default function PharmacyDetailPage() {
  const { id } = useParams();
  const router = useRouter();
  const [sidebarOpen, setSidebarOpen] = useState(true);
  const [data, setData] = useState<any>(null);
  const [loading, setLoading] = useState(true);
  const [selectedMonth, setSelectedMonth] = useState('all');

  useEffect(() => {
    if (id) fetchDetail();
  }, [id]);

  const fetchDetail = async () => {
    setLoading(true);
    try {
      const res = await fetch(`/api/admin/pharmacies/${id}`);
      const json = await res.json();
      if (json.success) setData(json.data);
    } catch (e) {
      console.error(e);
    } finally {
      setLoading(false);
    }
  };

  const statusColor = (status: string) => {
    const map: Record<string, string> = {
      delivered: 'bg-green-100 text-green-800',
      confirmed: 'bg-blue-100 text-blue-800',
      preparing: 'bg-yellow-100 text-yellow-800',
      in_transit: 'bg-purple-100 text-purple-800',
      cancelled: 'bg-red-100 text-red-800',
      pending: 'bg-gray-100 text-gray-800',
    };
    return map[status] || 'bg-gray-100 text-gray-800';
  };

  const monthLabel = (ym: string) => {
    const [y, m] = ym.split('-');
    return new Date(Number(y), Number(m) - 1, 1)
      .toLocaleString('default', { month: 'long', year: 'numeric' });
  };

  const emptyEarnings = {
    orders: 0,
    subtotal: 0,
    commission: 0,
    deliveryFee: 0,
    totalAmount: 0,
  };
  const earnings = data?.earnings || { allTime: emptyEarnings, monthly: [] };
  const currentEarnings =
    selectedMonth === 'all'
      ? earnings.allTime
      : earnings.monthly.find((m: any) => m.month === selectedMonth) ||
        emptyEarnings;

  return (
    <div className="flex h-screen bg-gray-50">
      <Sidebar isOpen={sidebarOpen} />
      <div className="flex-1 flex flex-col overflow-hidden">
        <header className="bg-white shadow-sm">
          <div className="flex items-center px-6 py-4">
            <button onClick={() => setSidebarOpen(!sidebarOpen)} className="text-gray-500 hover:text-gray-700">
              <svg className="w-6 h-6" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M4 6h16M4 12h16M4 18h16" />
              </svg>
            </button>
            <button onClick={() => router.back()} className="ml-3 text-gray-500 hover:text-gray-700">
              <svg className="w-5 h-5" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M15 19l-7-7 7-7" />
              </svg>
            </button>
            <h1 className="ml-3 text-2xl font-semibold text-gray-800">
              {loading ? 'Loading...' : data?.pharmacy?.name || 'Pharmacy Details'}
            </h1>
          </div>
        </header>

        <main className="flex-1 overflow-y-auto p-6">
          {loading ? (
            <div className="flex items-center justify-center h-full">
              <div className="text-gray-500">Loading pharmacy details...</div>
            </div>
          ) : !data ? (
            <div className="text-center text-gray-500 mt-20">Pharmacy not found</div>
          ) : (
            <>
              {/* Pharmacy Info Card */}
              <div className="bg-white rounded-xl shadow-sm border border-gray-100 p-6 mb-6">
                <div className="flex items-start justify-between">
                  <div className="flex items-center">
                    <div className="w-16 h-16 bg-purple-100 rounded-2xl flex items-center justify-center text-purple-600 text-2xl font-bold mr-4">
                      {data.pharmacy.name?.charAt(0)}
                    </div>
                    <div>
                      <h2 className="text-xl font-bold text-gray-800">{data.pharmacy.name}</h2>
                      <p className="text-gray-500 text-sm">{data.pharmacy.email}</p>
                      <p className="text-gray-500 text-sm">{data.pharmacy.phone}</p>
                    </div>
                  </div>
                  <div className="flex gap-2">
                    <span className={`px-3 py-1 rounded-full text-xs font-medium ${data.pharmacy.isActive ? 'bg-green-100 text-green-800' : 'bg-red-100 text-red-800'}`}>
                      {data.pharmacy.isActive ? 'Active' : 'Inactive'}
                    </span>
                    <span className={`px-3 py-1 rounded-full text-xs font-medium ${data.pharmacy.approvalStatus === 'approved' ? 'bg-blue-100 text-blue-800' : 'bg-yellow-100 text-yellow-800'}`}>
                      {data.pharmacy.approvalStatus}
                    </span>
                  </div>
                </div>

                <div className="grid grid-cols-2 md:grid-cols-4 gap-4 mt-6 pt-6 border-t border-gray-100">
                  <div>
                    <p className="text-xs text-gray-500 mb-1">License Number</p>
                    <p className="font-medium text-gray-800">{data.pharmacy.licenseNumber}</p>
                  </div>
                  <div>
                    <p className="text-xs text-gray-500 mb-1">Address</p>
                    <p className="font-medium text-gray-800 text-sm">{data.pharmacy.address}</p>
                  </div>
                  <div>
                    <p className="text-xs text-gray-500 mb-1">Rating</p>
                    <p className="font-medium text-gray-800">⭐ {data.pharmacy.rating?.toFixed(1) || '0.0'}</p>
                  </div>
                  <div>
                    <p className="text-xs text-gray-500 mb-1">Member Since</p>
                    <p className="font-medium text-gray-800">{new Date(data.pharmacy.createdAt).toLocaleDateString()}</p>
                  </div>
                </div>
              </div>

              {/* Earnings & Commission */}
              <div className="bg-white rounded-xl shadow-sm border border-gray-100 p-6 mb-6">
                <div className="flex items-center justify-between mb-5 flex-wrap gap-3">
                  <div>
                    <h3 className="text-lg font-semibold text-gray-800">Earnings & Commission</h3>
                    <p className="text-sm text-gray-500">
                      Commission is the amount this pharmacy owes the platform.
                    </p>
                  </div>
                  <select
                    value={selectedMonth}
                    onChange={(e) => setSelectedMonth(e.target.value)}
                    className="border border-gray-200 rounded-lg px-3 py-2 text-sm text-gray-700 focus:outline-none focus:ring-2 focus:ring-green-500"
                  >
                    <option value="all">All time</option>
                    {earnings.monthly.map((m: any) => (
                      <option key={m.month} value={m.month}>{monthLabel(m.month)}</option>
                    ))}
                  </select>
                </div>

                <div className="grid grid-cols-2 md:grid-cols-4 gap-4">
                  <div className="rounded-xl border border-green-200 bg-green-50 p-4">
                    <p className="text-xs text-gray-600 mb-1">Commission owed to us</p>
                    <h3 className="text-2xl font-bold text-green-700">
                      {currentEarnings.commission.toLocaleString()} MRO
                    </h3>
                  </div>
                  <div className="rounded-xl border border-gray-100 bg-gray-50 p-4">
                    <p className="text-xs text-gray-500 mb-1">Pharmacy earnings</p>
                    <h3 className="text-2xl font-bold text-gray-800">
                      {currentEarnings.subtotal.toLocaleString()} MRO
                    </h3>
                  </div>
                  <div className="rounded-xl border border-gray-100 bg-gray-50 p-4">
                    <p className="text-xs text-gray-500 mb-1">Delivered orders</p>
                    <h3 className="text-2xl font-bold text-gray-800">{currentEarnings.orders}</h3>
                  </div>
                  <div className="rounded-xl border border-gray-100 bg-gray-50 p-4">
                    <p className="text-xs text-gray-500 mb-1">Total collected</p>
                    <h3 className="text-2xl font-bold text-gray-800">
                      {currentEarnings.totalAmount.toLocaleString()} MRO
                    </h3>
                  </div>
                </div>

                {earnings.monthly.length > 0 && (
                  <div className="mt-6 overflow-x-auto">
                    <table className="w-full">
                      <thead>
                        <tr className="border-b border-gray-200 bg-gray-50">
                          {['Month', 'Delivered', 'Pharmacy Earnings', 'Commission (owed)', 'Total Collected'].map(h => (
                            <th key={h} className="text-left py-2 px-4 text-xs font-semibold text-gray-600">{h}</th>
                          ))}
                        </tr>
                      </thead>
                      <tbody>
                        {earnings.monthly.map((m: any) => (
                          <tr
                            key={m.month}
                            className={`border-b border-gray-100 hover:bg-gray-50 ${selectedMonth === m.month ? 'bg-green-50/60' : ''}`}
                          >
                            <td className="py-2 px-4 text-sm font-medium text-gray-800">{monthLabel(m.month)}</td>
                            <td className="py-2 px-4 text-sm text-gray-600">{m.orders}</td>
                            <td className="py-2 px-4 text-sm text-gray-800">{m.subtotal.toLocaleString()} MRO</td>
                            <td className="py-2 px-4 text-sm font-semibold text-green-700">{m.commission.toLocaleString()} MRO</td>
                            <td className="py-2 px-4 text-sm text-gray-800">{m.totalAmount.toLocaleString()} MRO</td>
                          </tr>
                        ))}
                      </tbody>
                    </table>
                  </div>
                )}
              </div>

              {/* Stats Grid */}
              <div className="grid grid-cols-2 md:grid-cols-4 gap-6 mb-6">
                {[
                  { label: 'Total Orders', value: data.stats.totalOrders, icon: '📦', color: 'bg-blue-500' },
                  { label: 'Total Revenue', value: `${data.stats.totalRevenue.toLocaleString()} MRO`, icon: '💰', color: 'bg-green-500' },
                  { label: 'Delivered', value: data.stats.deliveredOrders, icon: '✅', color: 'bg-emerald-500' },
                  { label: 'Acceptance Rate', value: `${data.stats.acceptanceRate}%`, icon: '📊', color: 'bg-purple-500' },
                  { label: 'Pending Orders', value: data.stats.pendingOrders, icon: '⏳', color: 'bg-yellow-500' },
                  { label: 'Cancelled', value: data.stats.cancelledOrders, icon: '❌', color: 'bg-red-500' },
                  { label: 'Prescriptions', value: data.stats.totalPrescriptions, icon: '📋', color: 'bg-indigo-500' },
                  { label: 'Quotes Sent', value: data.stats.totalQuotes, icon: '💬', color: 'bg-pink-500' },
                ].map((s, i) => (
                  <div key={i} className="bg-white rounded-xl shadow-sm p-5 border border-gray-100">
                    <div className="flex items-center justify-between">
                      <div>
                        <p className="text-xs text-gray-500 mb-1">{s.label}</p>
                        <h3 className="text-xl font-bold text-gray-800">{s.value}</h3>
                      </div>
                      <div className={`${s.color} w-10 h-10 rounded-full flex items-center justify-center`}>
                        <span className="text-lg">{s.icon}</span>
                      </div>
                    </div>
                  </div>
                ))}
              </div>

              <div className="grid grid-cols-1 lg:grid-cols-2 gap-6 mb-6">
                {/* Monthly Revenue */}
                <div className="bg-white rounded-xl shadow-sm border border-gray-100 p-6">
                  <h3 className="text-lg font-semibold text-gray-800 mb-4">Monthly Revenue</h3>
                  {data.monthlyRevenue.length === 0 ? (
                    <p className="text-gray-400 text-sm">No revenue data yet</p>
                  ) : (
                    <div className="space-y-3">
                      {data.monthlyRevenue.map((m: any) => (
                        <div key={m._id} className="flex items-center justify-between">
                          <span className="text-sm text-gray-600">{m._id}</span>
                          <div className="flex items-center gap-3">
                            <div className="w-32 bg-gray-100 rounded-full h-2">
                              <div
                                className="bg-green-500 h-2 rounded-full"
                                style={{ width: `${Math.min((m.revenue / (data.stats.totalRevenue || 1)) * 100, 100)}%` }}
                              />
                            </div>
                            <span className="text-sm font-medium text-gray-800 w-24 text-right">
                              {m.revenue.toLocaleString()} MRO
                            </span>
                            <span className="text-xs text-gray-400">{m.count} orders</span>
                          </div>
                        </div>
                      ))}
                    </div>
                  )}
                </div>

                {/* Order Status Breakdown */}
                <div className="bg-white rounded-xl shadow-sm border border-gray-100 p-6">
                  <h3 className="text-lg font-semibold text-gray-800 mb-4">Order Status Breakdown</h3>
                  {data.statusBreakdown.length === 0 ? (
                    <p className="text-gray-400 text-sm">No orders yet</p>
                  ) : (
                    <div className="space-y-3">
                      {data.statusBreakdown.map((s: any) => (
                        <div key={s._id} className="flex items-center justify-between">
                          <span className={`px-2 py-1 rounded-full text-xs font-medium capitalize ${statusColor(s._id)}`}>
                            {s._id}
                          </span>
                          <div className="flex items-center gap-3">
                            <div className="w-32 bg-gray-100 rounded-full h-2">
                              <div
                                className="bg-blue-500 h-2 rounded-full"
                                style={{ width: `${Math.min((s.count / (data.stats.totalOrders || 1)) * 100, 100)}%` }}
                              />
                            </div>
                            <span className="text-sm font-medium text-gray-800">{s.count}</span>
                          </div>
                        </div>
                      ))}
                    </div>
                  )}
                </div>
              </div>

              {/* Recent Orders */}
              <div className="bg-white rounded-xl shadow-sm border border-gray-100">
                <div className="p-6 border-b border-gray-200">
                  <h3 className="text-lg font-semibold text-gray-800">Recent Orders</h3>
                </div>
                {data.recentOrders.length === 0 ? (
                  <div className="p-8 text-center text-gray-400">No orders yet</div>
                ) : (
                  <div className="overflow-x-auto">
                    <table className="w-full">
                      <thead>
                        <tr className="border-b border-gray-200 bg-gray-50">
                          {['Order #', 'Amount', 'Payment', 'Status', 'Date'].map(h => (
                            <th key={h} className="text-left py-3 px-6 text-sm font-semibold text-gray-600">{h}</th>
                          ))}
                        </tr>
                      </thead>
                      <tbody>
                        {data.recentOrders.map((o: any) => (
                          <tr key={o.id} className="border-b border-gray-100 hover:bg-gray-50">
                            <td className="py-3 px-6 font-medium text-gray-800 text-sm">{o.orderNumber}</td>
                            <td className="py-3 px-6 font-medium text-gray-800">{o.totalAmount?.toLocaleString()} MRO</td>
                            <td className="py-3 px-6 text-gray-600 capitalize text-sm">{o.paymentMethod || 'cash'}</td>
                            <td className="py-3 px-6">
                              <span className={`px-2 py-1 rounded-full text-xs font-medium capitalize ${statusColor(o.status)}`}>
                                {o.status}
                              </span>
                            </td>
                            <td className="py-3 px-6 text-gray-500 text-sm">
                              {new Date(o.createdAt).toLocaleDateString()}
                            </td>
                          </tr>
                        ))}
                      </tbody>
                    </table>
                  </div>
                )}
              </div>
            </>
          )}
        </main>
      </div>
    </div>
  );
}
