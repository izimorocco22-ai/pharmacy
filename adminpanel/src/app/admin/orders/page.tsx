'use client';

import { useState, useEffect } from 'react';
import Sidebar from '@/components/admin/Sidebar';

interface Order {
  _id: string;
  orderNumber: string;
  patientName?: string;
  patientEmail?: string;
  patientPhone?: string;
  patientImage?: string;
  pharmacyId?: { pharmacyName: string };
  riderId?: { fullName: string };
  riderName?: string;
  totalAmount: number;
  status: string;
  createdAt: string;
}

interface OrderDetail {
  id: string;
  orderNumber: string;
  status: string;
  paymentMethod?: string;
  paymentStatus?: string;
  subtotal: number;
  commissionAmount: number;
  deliveryFee: number;
  totalAmount: number;
  createdAt: string;
  deliveredAt?: string;
  estimatedDeliveryTime?: string;
  patient?: { fullName: string; email: string; phone: string; profileImage?: string };
  pharmacy?: { name: string; address: string };
  rider?: { name: string; phone: string; vehicleType: string; vehicleNumber: string; rating: number; totalDeliveries: number };
  deliveryAddress: string;
  pharmacyAddress: string;
  prescription?: { imageUrl: string; medicines: { name: string; quantity: number }[] };
  items: { medicineName: string; quantity: number; unitPrice: number; totalPrice: number }[];
  quoteHistory: {
    id: string;
    pharmacyName: string;
    pharmacyAddress: string;
    status: string;
    rejectionReason: string;
    subtotal: number;
    deliveryFee: number;
    totalAmount: number;
    items: { medicineName: string; quantity: number; unitPrice: number; totalPrice: number }[];
    createdAt: string;
  }[];
}

export default function OrdersPage() {
  const [sidebarOpen, setSidebarOpen] = useState(true);
  const [selectedStatus, setSelectedStatus] = useState('all');
  const [search, setSearch] = useState('');
  const [dateFrom, setDateFrom] = useState('');
  const [dateTo, setDateTo] = useState('');
  const [orders, setOrders] = useState<Order[]>([]);
  const [loading, setLoading] = useState(true);
  const [pagination, setPagination] = useState({ page: 1, total: 0, pages: 1 });
  const [selectedOrder, setSelectedOrder] = useState<OrderDetail | null>(null);
  const [detailLoading, setDetailLoading] = useState(false);

  useEffect(() => { fetchOrders(); }, [selectedStatus, search, dateFrom, dateTo, pagination.page]);

  const fetchOrders = async () => {
    try {
      setLoading(true);
      const params = new URLSearchParams({ page: String(pagination.page), limit: '10' });
      if (selectedStatus !== 'all') params.set('status', selectedStatus);
      if (search.trim()) params.set('search', search.trim());
      if (dateFrom) params.set('dateFrom', dateFrom);
      if (dateTo) params.set('dateTo', dateTo);
      const res = await fetch(`/api/orders?${params}`);
      const data = await res.json() as any;
      if (data.success) {
        setOrders(Array.isArray(data.data?.orders) ? data.data.orders : []);
        setPagination(p => ({ ...p, total: data.data?.pagination?.total || 0, pages: data.data?.pagination?.pages || 1 }));
      }
    } catch (e) { console.error(e); }
    finally { setLoading(false); }
  };

  const resetFilters = () => { setSelectedStatus('all'); setSearch(''); setDateFrom(''); setDateTo(''); setPagination(p => ({ ...p, page: 1 })); };
  const hasFilters = selectedStatus !== 'all' || search || dateFrom || dateTo;

  const fetchOrderDetail = async (id: string) => {
    setDetailLoading(true);
    setSelectedOrder(null);
    try {
      const res = await fetch(`/api/orders/${id}`, { credentials: 'include' });
      const data = await res.json() as any;
      if (data.success) setSelectedOrder(data.data.order);
      else console.error('Order detail error:', data.message);
    } catch (e) { console.error(e); }
    finally { setDetailLoading(false); }
  };

  const getPatientName = (o: Order) => o.patientName || 'Unknown';

  const statusColor = (s: string) => {
    const map: Record<string, string> = {
      delivered: 'bg-green-100 text-green-800',
      in_transit: 'bg-blue-100 text-blue-800',
      picked_up: 'bg-cyan-100 text-cyan-800',
      assigned: 'bg-indigo-100 text-indigo-800',
      preparing: 'bg-yellow-100 text-yellow-800',
      ready: 'bg-lime-100 text-lime-800',
      confirmed: 'bg-purple-100 text-purple-800',
      cancelled: 'bg-red-100 text-red-800',
      pending: 'bg-orange-100 text-orange-800',
      rejected: 'bg-red-100 text-red-700',
      accepted: 'bg-green-100 text-green-700',
    };
    return map[s] || 'bg-gray-100 text-gray-800';
  };

  const statusLabel = (s: string) => s.charAt(0).toUpperCase() + s.slice(1).replace(/_/g, ' ');

  const fmt = (d?: string) => d ? new Date(d).toLocaleString() : '—';
  const fmtDate = (d: string) => new Date(d).toLocaleDateString();

  return (
    <div className="flex h-screen bg-gray-50">
      <Sidebar isOpen={sidebarOpen} />
      <div className="flex-1 flex flex-col overflow-hidden">
        <header className="bg-white shadow-sm">
          <div className="flex items-center px-6 py-4 gap-4">
            <button onClick={() => setSidebarOpen(!sidebarOpen)} className="text-gray-500 hover:text-gray-700">
              <svg className="w-6 h-6" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M4 6h16M4 12h16M4 18h16" />
              </svg>
            </button>
            <h1 className="text-2xl font-semibold text-gray-800">Orders Management</h1>
          </div>
        </header>

        <main className="flex-1 overflow-y-auto p-6">
          {/* Filters toolbar */}
          <div className="mb-6 flex flex-wrap items-center gap-3">
            {/* Status dropdown */}
            <select
              value={selectedStatus}
              onChange={e => { setSelectedStatus(e.target.value); setPagination(p => ({ ...p, page: 1 })); }}
              className="px-4 py-2 rounded-lg border border-gray-200 bg-white text-sm text-gray-700 font-medium focus:outline-none focus:ring-2 focus:ring-green-400">
              {['all', 'pending', 'confirmed', 'preparing', 'ready', 'assigned', 'picked_up', 'in_transit', 'delivered', 'cancelled'].map(s => (
                <option key={s} value={s}>{statusLabel(s)}</option>
              ))}
            </select>

            {/* Date range */}
            <div className="flex items-center gap-2">
              <input type="date" value={dateFrom}
                onChange={e => { setDateFrom(e.target.value); setPagination(p => ({ ...p, page: 1 })); }}
                className="px-3 py-2 rounded-lg border border-gray-200 bg-white text-sm text-gray-700 focus:outline-none focus:ring-2 focus:ring-green-400" />
              <span className="text-gray-400 text-sm">to</span>
              <input type="date" value={dateTo}
                onChange={e => { setDateTo(e.target.value); setPagination(p => ({ ...p, page: 1 })); }}
                className="px-3 py-2 rounded-lg border border-gray-200 bg-white text-sm text-gray-700 focus:outline-none focus:ring-2 focus:ring-green-400" />
            </div>

            {/* Clear filters */}
            {hasFilters && (
              <button onClick={resetFilters} className="px-3 py-2 rounded-lg border border-gray-200 bg-white text-sm text-red-500 hover:bg-red-50 font-medium">
                ✕ Clear
              </button>
            )}

            {/* Search — pushed to the right */}
            <div className="relative ml-auto">
              <svg className="absolute left-3 top-1/2 -translate-y-1/2 w-4 h-4 text-gray-400" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M21 21l-4.35-4.35M17 11A6 6 0 1 1 5 11a6 6 0 0 1 12 0z" />
              </svg>
              <input
                type="text" placeholder="Search order, patient, pharmacy, rider..."
                value={search}
                onChange={e => { setSearch(e.target.value); setPagination(p => ({ ...p, page: 1 })); }}
                className="pl-9 pr-4 py-2 rounded-lg border border-gray-200 bg-white text-sm text-gray-700 focus:outline-none focus:ring-2 focus:ring-green-400 w-64"
              />
            </div>
          </div>

          <div className="bg-white rounded-xl shadow-sm border border-gray-100">
            <div className="overflow-x-auto">
              {loading ? (
                <div className="p-8 text-center text-gray-500">Loading orders...</div>
              ) : orders.length === 0 ? (
                <div className="p-8 text-center text-gray-500">No orders found</div>
              ) : (
                <table className="w-full">
                  <thead>
                    <tr className="border-b border-gray-200 bg-gray-50">
                      {['Order ID', 'Patient', 'Pharmacy', 'Rider', 'Amount', 'Status', 'Date', 'Actions'].map(h => (
                        <th key={h} className="text-left py-4 px-6 text-sm font-semibold text-gray-600">{h}</th>
                      ))}
                    </tr>
                  </thead>
                  <tbody>
                    {orders.map(order => (
                      <tr key={order._id} className="border-b border-gray-100 hover:bg-gray-50 transition-colors">
                        <td className="py-4 px-6 font-medium text-gray-800">{order.orderNumber || order._id.slice(-6).toUpperCase()}</td>
                        <td className="py-4 px-6 text-gray-600">{getPatientName(order)}</td>
                        <td className="py-4 px-6 text-gray-600">{order.pharmacyId?.pharmacyName || '—'}</td>
                        <td className="py-4 px-6 text-gray-600">{(order as any).riderName || order.riderId?.fullName || 'Unassigned'}</td>
                        <td className="py-4 px-6 font-medium text-gray-800">{order.totalAmount} MRO</td>
                        <td className="py-4 px-6">
                          <span className={`px-3 py-1 rounded-full text-xs font-medium ${statusColor(order.status)}`}>{statusLabel(order.status)}</span>
                        </td>
                        <td className="py-4 px-6 text-sm text-gray-600">{fmtDate(order.createdAt)}</td>
                        <td className="py-4 px-6">
                          <button onClick={() => fetchOrderDetail(order._id)} className="text-green-600 hover:text-green-700 text-sm font-medium">
                            View Details
                          </button>
                        </td>
                      </tr>
                    ))}
                  </tbody>
                </table>
              )}
            </div>
            <div className="flex items-center justify-between px-6 py-4 border-t border-gray-200">
              <div className="text-sm text-gray-600">Total: <span className="font-medium">{pagination.total}</span> orders</div>
              <div className="flex items-center gap-1">
                <button onClick={() => setPagination(p => ({ ...p, page: Math.max(1, p.page - 1) }))} disabled={pagination.page === 1}
                  className="px-3 py-1.5 border border-gray-300 rounded-lg text-sm hover:bg-gray-50 disabled:opacity-50">‹</button>
                {(() => {
                  const { page, pages } = pagination;
                  const items: (number | '...')[] = [];
                  if (pages <= 4) {
                    for (let i = 1; i <= pages; i++) items.push(i);
                  } else {
                    items.push(1, 2);
                    if (page > 3) items.push('...');
                    if (page > 2 && page < pages - 1) items.push(page);
                    if (page < pages - 1) items.push('...');
                    items.push(pages);
                  }
                  return items.map((item, i) =>
                    item === '...' ? (
                      <span key={`dots-${i}`} className="px-2 py-1.5 text-sm text-gray-400">...</span>
                    ) : (
                      <button key={item} onClick={() => setPagination(p => ({ ...p, page: item as number }))}
                        className={`px-3 py-1.5 rounded-lg text-sm font-medium ${
                          page === item ? 'bg-green-500 text-white' : 'border border-gray-300 hover:bg-gray-50 text-gray-700'
                        }`}>{item}</button>
                    )
                  );
                })()}
                <button onClick={() => setPagination(p => ({ ...p, page: Math.min(p.pages, p.page + 1) }))} disabled={pagination.page === pagination.pages}
                  className="px-3 py-1.5 border border-gray-300 rounded-lg text-sm hover:bg-gray-50 disabled:opacity-50">›</button>
              </div>
            </div>
          </div>
        </main>
      </div>

      {/* Detail Modal */}
      {(selectedOrder || detailLoading) && (
        <div className="fixed inset-0 z-50 flex items-center justify-center bg-black/50 p-4">
          <div className="bg-white rounded-2xl shadow-2xl w-full max-w-3xl max-h-[92vh] overflow-y-auto">
            {detailLoading ? (
              <div className="p-16 text-center text-gray-500">
                <div className="animate-spin w-10 h-10 border-4 border-green-500 border-t-transparent rounded-full mx-auto mb-4" />
                Loading order details...
              </div>
            ) : selectedOrder && (
              <>
                {/* Header */}
                <div className="flex items-center justify-between px-6 py-4 border-b border-gray-200 sticky top-0 bg-white z-10">
                  <div>
                    <h2 className="text-xl font-semibold text-gray-800">Order Details</h2>
                    <p className="text-sm text-gray-500">{selectedOrder.orderNumber}</p>
                  </div>
                  <div className="flex items-center gap-3">
                    <span className={`px-3 py-1 rounded-full text-xs font-medium ${statusColor(selectedOrder.status)}`}>{statusLabel(selectedOrder.status)}</span>
                    <button onClick={() => setSelectedOrder(null)} className="text-gray-400 hover:text-gray-600">
                      <svg className="w-6 h-6" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                        <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M6 18L18 6M6 6l12 12" />
                      </svg>
                    </button>
                  </div>
                </div>

                <div className="p-6 space-y-5">

                  {/* Patient */}
                  <Section title="👤 Patient Information">
                    <div className="flex items-center gap-4">
                      {selectedOrder.patient?.profileImage ? (
                        <img src={selectedOrder.patient.profileImage} className="w-14 h-14 rounded-full object-cover border-2 border-gray-100" alt="" />
                      ) : (
                        <div className="w-14 h-14 rounded-full bg-green-100 flex items-center justify-center text-green-600 text-xl font-bold">
                          {selectedOrder.patient?.fullName?.charAt(0) || '?'}
                        </div>
                      )}
                      <div>
                        <p className="font-semibold text-gray-800 text-lg">{selectedOrder.patient?.fullName || '—'}</p>
                        <p className="text-sm text-gray-500">{selectedOrder.patient?.email || '—'}</p>
                        <p className="text-sm text-gray-500">{selectedOrder.patient?.phone || '—'}</p>
                      </div>
                    </div>
                  </Section>

                  {/* Addresses */}
                  <Section title="📍 Addresses">
                    <div className="grid grid-cols-1 md:grid-cols-2 gap-4">
                      <InfoRow label="Pickup (Pharmacy)" value={selectedOrder.pharmacyAddress || '—'} />
                      <InfoRow label="Delivery (Patient)" value={selectedOrder.deliveryAddress || '—'} />
                    </div>
                  </Section>

                  {/* Pharmacy */}
                  {selectedOrder.pharmacy && (
                    <Section title="🏥 Pharmacy">
                      <InfoRow label="Name" value={selectedOrder.pharmacy.name} />
                      <InfoRow label="Address" value={selectedOrder.pharmacy.address} />
                    </Section>
                  )}

                  {/* Rider */}
                  <Section title="🚴 Rider">
                    {selectedOrder.rider ? (
                      <div className="grid grid-cols-2 md:grid-cols-3 gap-3">
                        <InfoRow label="Name" value={selectedOrder.rider.name} />
                        <InfoRow label="Phone" value={selectedOrder.rider.phone} />
                        <InfoRow label="Vehicle" value={`${selectedOrder.rider.vehicleType} ${selectedOrder.rider.vehicleNumber ? `(${selectedOrder.rider.vehicleNumber})` : ''}`} />
                        <InfoRow label="Rating" value={`${selectedOrder.rider.rating}/5`} />
                        <InfoRow label="Total Deliveries" value={`${selectedOrder.rider.totalDeliveries}`} />
                      </div>
                    ) : (
                      <p className="text-gray-500 text-sm">No rider assigned yet</p>
                    )}
                  </Section>

                  {/* Prescription */}
                  {selectedOrder.prescription && (
                    <Section title="📋 Prescription">
                      {selectedOrder.prescription.imageUrl ? (
                        <img src={selectedOrder.prescription.imageUrl} alt="Prescription" className="w-full max-h-64 object-contain rounded-xl border border-gray-200" />
                      ) : selectedOrder.prescription.medicines?.length > 0 ? (
                        <div className="space-y-2">
                          {selectedOrder.prescription.medicines.map((m, i) => (
                            <div key={i} className="flex items-center justify-between bg-green-50 rounded-lg px-4 py-2">
                              <span className="text-sm font-medium text-gray-800">💊 {m.name}</span>
                              <span className="text-sm text-gray-500">Qty: {m.quantity}</span>
                            </div>
                          ))}
                        </div>
                      ) : (
                        <p className="text-gray-500 text-sm">No prescription image or medicines</p>
                      )}
                    </Section>
                  )}

                  {/* Confirmed order items */}
                  {selectedOrder.items?.length > 0 && (
                    <Section title="💊 Order Items">
                      <div className="space-y-2">
                        {selectedOrder.items.map((item, i) => (
                          <div key={i} className="flex items-center justify-between py-2 border-b border-gray-100 last:border-0">
                            <div>
                              <p className="text-sm font-medium text-gray-800">{item.medicineName}</p>
                              <p className="text-xs text-gray-500">Qty: {item.quantity} × {item.unitPrice} MRO</p>
                            </div>
                            <p className="text-sm font-semibold text-gray-800">{item.totalPrice} MRO</p>
                          </div>
                        ))}
                        <div className="pt-2 space-y-1">
                          <div className="flex justify-between text-sm text-gray-500"><span>Subtotal</span><span>{selectedOrder.subtotal} MRO</span></div>
                          {selectedOrder.commissionAmount > 0 && <div className="flex justify-between text-sm text-gray-500"><span>Service Fee</span><span>{selectedOrder.commissionAmount} MRO</span></div>}
                          <div className="flex justify-between text-sm text-gray-500"><span>Delivery Fee</span><span>{selectedOrder.deliveryFee} MRO</span></div>
                          <div className="flex justify-between text-base font-bold text-gray-800 pt-1 border-t border-gray-200"><span>Total</span><span>{selectedOrder.totalAmount} MRO</span></div>
                        </div>
                      </div>
                    </Section>
                  )}

                  {/* Order timeline */}
                  <Section title="📅 Order Timeline">
                    <div className="grid grid-cols-2 gap-3">
                      <InfoRow label="Created" value={fmt(selectedOrder.createdAt)} />
                      <InfoRow label="Payment" value={`${selectedOrder.paymentMethod?.toUpperCase() || '—'} (${selectedOrder.paymentStatus || '—'})`} />
                      {selectedOrder.estimatedDeliveryTime && <InfoRow label="Est. Delivery" value={fmt(selectedOrder.estimatedDeliveryTime)} />}
                      {selectedOrder.deliveredAt && <InfoRow label="Delivered At" value={fmt(selectedOrder.deliveredAt)} />}
                    </div>
                  </Section>

                  {/* Quote History */}
                  {selectedOrder.quoteHistory?.length > 0 && (
                    <Section title="📜 Quote History">
                      <div className="space-y-3">
                        {selectedOrder.quoteHistory.map((q, i) => (
                          <div key={q.id} className={`rounded-xl border p-4 ${q.status === 'accepted' ? 'border-green-200 bg-green-50' : q.status === 'rejected' ? 'border-red-200 bg-red-50' : 'border-gray-200 bg-gray-50'}`}>
                            <div className="flex items-start justify-between mb-2">
                              <div>
                                <div className="flex items-center gap-2">
                                  <span className="text-sm font-bold text-gray-800">#{i + 1} {q.pharmacyName}</span>
                                  <span className={`px-2 py-0.5 rounded-full text-xs font-medium ${statusColor(q.status)}`}>{statusLabel(q.status)}</span>
                                </div>
                                {q.pharmacyAddress && <p className="text-xs text-gray-500 mt-0.5">{q.pharmacyAddress}</p>}
                              </div>
                              <span className="text-xs text-gray-400">{fmt(q.createdAt)}</span>
                            </div>

                            {/* Rejection reason */}
                            {q.status === 'rejected' && q.rejectionReason && (
                              <div className="mt-2 flex items-start gap-2 bg-red-100 rounded-lg px-3 py-2">
                                <span className="text-red-500 text-sm">⚠️</span>
                                <p className="text-sm text-red-700"><span className="font-medium">Reason:</span> {q.rejectionReason}</p>
                              </div>
                            )}

                            {/* Quote items if accepted */}
                            {q.status === 'accepted' && q.items?.length > 0 && (
                              <div className="mt-3 space-y-1">
                                {q.items.map((item, j) => (
                                  <div key={j} className="flex justify-between text-sm">
                                    <span className="text-gray-700">{item.medicineName} × {item.quantity}</span>
                                    <span className="text-gray-600">{item.totalPrice} MRO</span>
                                  </div>
                                ))}
                                <div className="flex justify-between text-sm font-semibold text-green-700 pt-1 border-t border-green-200 mt-1">
                                  <span>Total</span><span>{q.totalAmount} MRO</span>
                                </div>
                              </div>
                            )}

                            {/* Pending quote summary */}
                            {q.status === 'pending' && q.totalAmount > 0 && (
                              <p className="text-sm text-gray-600 mt-1">Quote: <span className="font-medium">{q.totalAmount} MRO</span></p>
                            )}
                          </div>
                        ))}
                      </div>
                    </Section>
                  )}

                </div>

                <div className="px-6 pb-6">
                  <button onClick={() => setSelectedOrder(null)} className="w-full py-2.5 bg-gray-100 hover:bg-gray-200 text-gray-700 font-medium rounded-xl transition-colors">
                    Close
                  </button>
                </div>
              </>
            )}
          </div>
        </div>
      )}
    </div>
  );
}

function Section({ title, children }: { title: string; children: React.ReactNode }) {
  return (
    <div className="bg-gray-50 rounded-xl p-4">
      <h3 className="text-sm font-semibold text-gray-600 mb-3">{title}</h3>
      {children}
    </div>
  );
}

function InfoRow({ label, value }: { label: string; value: string }) {
  return (
    <div>
      <p className="text-xs text-gray-500">{label}</p>
      <p className="text-sm font-medium text-gray-800">{value || '—'}</p>
    </div>
  );
}
