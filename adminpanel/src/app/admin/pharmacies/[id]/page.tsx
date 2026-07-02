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
  const [modalOpen, setModalOpen] = useState(false);
  const [payAmount, setPayAmount] = useState('');
  const [payNote, setPayNote] = useState('');
  const [payType, setPayType] = useState<'payment' | 'adjustment'>('payment');
  const [saving, setSaving] = useState(false);
  const [duesOpen, setDuesOpen] = useState(false);

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

  const recordSettlement = async (amount: number, note: string, type: string) => {
    setSaving(true);
    try {
      const res = await fetch(`/api/admin/pharmacies/${id}/settlements`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ amount, note, type }),
      });
      const json = await res.json();
      if (!json.success) {
        alert(json.message || 'Failed to record');
        return;
      }
      setModalOpen(false);
      setPayAmount('');
      setPayNote('');
      setPayType('payment');
      await fetchDetail();
    } catch (e) {
      alert('Failed to record payment');
    } finally {
      setSaving(false);
    }
  };

  const submitModal = () => {
    const amt = parseFloat(payAmount);
    if (!amt || isNaN(amt)) {
      alert('Enter a valid amount');
      return;
    }
    recordSettlement(amt, payNote, payType);
  };

  const clearDue = async () => {
    const due = data?.settlement?.due || 0;
    if (due <= 0) {
      alert('No outstanding due to clear.');
      return;
    }
    if (!confirm(`Clear the full outstanding due of ${due.toLocaleString()} MRO? This records a payment for the full amount.`)) {
      return;
    }
    await recordSettlement(due, 'Cleared full outstanding due', 'payment');
  };

  const deleteSettlement = async (sid: string) => {
    if (!confirm('Remove this record? The balance will be recalculated.')) return;
    try {
      const res = await fetch(`/api/admin/pharmacies/${id}/settlements/${sid}`, {
        method: 'DELETE',
      });
      const json = await res.json();
      if (json.success) await fetchDetail();
      else alert(json.message || 'Failed to remove');
    } catch (e) {
      alert('Failed to remove record');
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

  // Always offer the last 12 months in the filter (plus any older month that
  // actually has data), so the admin can pick a month even before there are
  // delivered orders in it.
  const monthOptions = (() => {
    const set = new Set<string>();
    const now = new Date();
    for (let i = 0; i < 12; i++) {
      const d = new Date(now.getFullYear(), now.getMonth() - i, 1);
      set.add(`${d.getFullYear()}-${String(d.getMonth() + 1).padStart(2, '0')}`);
    }
    earnings.monthly.forEach((m: any) => set.add(m.month));
    return Array.from(set).sort().reverse();
  })();

  const settlement = data?.settlement || { totalCommission: 0, totalPaid: 0, due: 0 };
  const settlements: any[] = data?.settlements || [];

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
                    {monthOptions.map((m: string) => (
                      <option key={m} value={m}>{monthLabel(m)}</option>
                    ))}
                  </select>
                </div>

                <div className="grid grid-cols-2 md:grid-cols-3 lg:grid-cols-5 gap-4">
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
                    <p className="text-xs text-gray-500 mb-1">Delivery charges</p>
                    <h3 className="text-2xl font-bold text-gray-800">
                      {(currentEarnings.deliveryFee || 0).toLocaleString()} MRO
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
                          {['Month', 'Delivered', 'Pharmacy Earnings', 'Delivery', 'Commission (owed)', 'Total Collected'].map(h => (
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
                            <td className="py-2 px-4 text-sm text-gray-800">{(m.deliveryFee || 0).toLocaleString()} MRO</td>
                            <td className="py-2 px-4 text-sm font-semibold text-green-700">{m.commission.toLocaleString()} MRO</td>
                            <td className="py-2 px-4 text-sm text-gray-800">{m.totalAmount.toLocaleString()} MRO</td>
                          </tr>
                        ))}
                      </tbody>
                    </table>
                  </div>
                )}
              </div>

              {/* Commission Dues & Payments */}
              <div className="bg-white rounded-xl shadow-sm border border-gray-100 p-6 mb-6">
                <button
                  onClick={() => setDuesOpen(!duesOpen)}
                  className="w-full flex items-center justify-between text-left gap-3"
                >
                  <div>
                    <h3 className="text-lg font-semibold text-gray-800">Commission Dues & Payments</h3>
                    <p className="text-sm text-gray-500">
                      Record what the pharmacy pays and clear their balance at month-end.
                    </p>
                  </div>
                  <div className="flex items-center gap-3">
                    <span
                      className={`px-3 py-1 rounded-full text-sm font-semibold whitespace-nowrap ${
                        (settlement.due || 0) > 0
                          ? 'bg-red-100 text-red-700'
                          : 'bg-green-100 text-green-700'
                      }`}
                    >
                      Due: {(settlement.due || 0).toLocaleString()} MRO
                    </span>
                    <svg
                      className={`w-5 h-5 text-gray-400 transition-transform ${duesOpen ? 'rotate-180' : ''}`}
                      fill="none"
                      stroke="currentColor"
                      viewBox="0 0 24 24"
                    >
                      <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M19 9l-7 7-7-7" />
                    </svg>
                  </div>
                </button>

                {duesOpen && (
                <div className="mt-5">
                <div className="flex gap-2 justify-end mb-4">
                  <button
                    onClick={() => setModalOpen(true)}
                    className="px-4 py-2 rounded-lg text-sm font-medium bg-gray-100 text-gray-700 hover:bg-gray-200"
                  >
                    Record payment
                  </button>
                  <button
                    onClick={clearDue}
                    disabled={(settlement.due || 0) <= 0}
                    className="px-4 py-2 rounded-lg text-sm font-medium bg-green-600 text-white hover:bg-green-700 disabled:opacity-40 disabled:cursor-not-allowed"
                  >
                    Clear due
                  </button>
                </div>

                <div className="grid grid-cols-1 md:grid-cols-3 gap-4">
                  <div className="rounded-xl border border-gray-100 bg-gray-50 p-4">
                    <p className="text-xs text-gray-500 mb-1">Total commission (all time)</p>
                    <h3 className="text-2xl font-bold text-gray-800">
                      {(settlement.totalCommission || 0).toLocaleString()} MRO
                    </h3>
                  </div>
                  <div className="rounded-xl border border-gray-100 bg-gray-50 p-4">
                    <p className="text-xs text-gray-500 mb-1">Total paid</p>
                    <h3 className="text-2xl font-bold text-gray-800">
                      {(settlement.totalPaid || 0).toLocaleString()} MRO
                    </h3>
                  </div>
                  <div
                    className={`rounded-xl border p-4 ${
                      (settlement.due || 0) > 0
                        ? 'border-red-200 bg-red-50'
                        : 'border-green-200 bg-green-50'
                    }`}
                  >
                    <p className="text-xs text-gray-600 mb-1">Outstanding due</p>
                    <h3
                      className={`text-2xl font-bold ${
                        (settlement.due || 0) > 0 ? 'text-red-600' : 'text-green-700'
                      }`}
                    >
                      {(settlement.due || 0).toLocaleString()} MRO
                    </h3>
                  </div>
                </div>

                {settlements.length > 0 && (
                  <div className="mt-6 overflow-x-auto">
                    <p className="text-sm font-semibold text-gray-700 mb-2">Payment history</p>
                    <table className="w-full">
                      <thead>
                        <tr className="border-b border-gray-200 bg-gray-50">
                          {['Date', 'Type', 'Note', 'Amount', ''].map(h => (
                            <th key={h} className="text-left py-2 px-4 text-xs font-semibold text-gray-600">{h}</th>
                          ))}
                        </tr>
                      </thead>
                      <tbody>
                        {settlements.map((s: any) => (
                          <tr key={s.id} className="border-b border-gray-100 hover:bg-gray-50">
                            <td className="py-2 px-4 text-sm text-gray-600">{new Date(s.createdAt).toLocaleDateString()}</td>
                            <td className="py-2 px-4 text-sm capitalize text-gray-700">{s.type}</td>
                            <td className="py-2 px-4 text-sm text-gray-600">{s.note || '-'}</td>
                            <td className="py-2 px-4 text-sm font-semibold text-gray-800">{(s.amount || 0).toLocaleString()} MRO</td>
                            <td className="py-2 px-4 text-right">
                              <button onClick={() => deleteSettlement(s.id)} className="text-red-500 hover:text-red-700 text-xs">Remove</button>
                            </td>
                          </tr>
                        ))}
                      </tbody>
                    </table>
                  </div>
                )}
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

              {/* Record payment modal */}
              {modalOpen && (
                <div
                  className="fixed inset-0 bg-black/40 flex items-center justify-center z-50 p-4"
                  onClick={() => setModalOpen(false)}
                >
                  <div
                    className="bg-white rounded-xl shadow-lg w-full max-w-md p-6"
                    onClick={(e) => e.stopPropagation()}
                  >
                    <h3 className="text-lg font-semibold text-gray-800 mb-1">Record payment</h3>
                    <p className="text-sm text-gray-500 mb-4">
                      Outstanding due: {(settlement.due || 0).toLocaleString()} MRO
                    </p>

                    <label className="block text-xs text-gray-500 mb-1">Type</label>
                    <select
                      value={payType}
                      onChange={(e) => setPayType(e.target.value as 'payment' | 'adjustment')}
                      className="w-full border border-gray-200 rounded-lg px-3 py-2 text-sm mb-3"
                    >
                      <option value="payment">Payment (pharmacy paid us)</option>
                      <option value="adjustment">Adjustment / discount</option>
                    </select>

                    <label className="block text-xs text-gray-500 mb-1">Amount (MRO)</label>
                    <input
                      type="number"
                      value={payAmount}
                      onChange={(e) => setPayAmount(e.target.value)}
                      placeholder="0"
                      className="w-full border border-gray-200 rounded-lg px-3 py-2 text-sm mb-3"
                    />

                    <label className="block text-xs text-gray-500 mb-1">Note (optional)</label>
                    <input
                      type="text"
                      value={payNote}
                      onChange={(e) => setPayNote(e.target.value)}
                      placeholder="e.g. June 2026 settlement"
                      className="w-full border border-gray-200 rounded-lg px-3 py-2 text-sm mb-4"
                    />

                    <div className="flex justify-end gap-2">
                      <button
                        onClick={() => setModalOpen(false)}
                        className="px-4 py-2 rounded-lg text-sm bg-gray-100 text-gray-700 hover:bg-gray-200"
                      >
                        Cancel
                      </button>
                      <button
                        onClick={submitModal}
                        disabled={saving}
                        className="px-4 py-2 rounded-lg text-sm bg-green-600 text-white hover:bg-green-700 disabled:opacity-50"
                      >
                        {saving ? 'Saving...' : 'Save'}
                      </button>
                    </div>
                  </div>
                </div>
              )}
            </>
          )}
        </main>
      </div>
    </div>
  );
}
