'use client';

import { useState, useEffect } from 'react';
import Sidebar from '@/components/admin/Sidebar';

interface Prescription {
  _id: string;
  patientName: string;
  patientPhone: string;
  patientEmail: string;
  imageUrl: string;
  medicines: { name: string; quantity: number }[];
  status: string;
  deliveryAddress: string;
  quotesCount: number;
  acceptedQuotes: number;
  rejectedQuotes: number;
  quoteHistory: {
    pharmacyName: string;
    status: string;
    rejectedBy: 'pharmacy' | 'patient' | null;
    rejectionReason: string;
    totalAmount: number;
    subtotal: number;
    deliveryFee: number;
    items: { medicineName: string; quantity: number; unitPrice: number; totalPrice: number }[];
    createdAt: string;
  }[];
  createdAt: string;
  expiresAt: string;
}

export default function PrescriptionsPage() {
  const [sidebarOpen, setSidebarOpen] = useState(true);
  const [prescriptions, setPrescriptions] = useState<Prescription[]>([]);
  const [loading, setLoading] = useState(true);
  const [filterStatus, setFilterStatus] = useState('');
  const [search, setSearch] = useState('');
  const [dateFrom, setDateFrom] = useState('');
  const [dateTo, setDateTo] = useState('');
  const [pagination, setPagination] = useState({ page: 1, total: 0, pages: 1 });
  const [selected, setSelected] = useState<Prescription | null>(null);

  useEffect(() => { fetchPrescriptions(); }, [filterStatus, search, dateFrom, dateTo, pagination.page]);

  const fetchPrescriptions = async () => {
    setLoading(true);
    try {
      const params = new URLSearchParams({ page: String(pagination.page), limit: '10' });
      if (filterStatus) params.set('status', filterStatus);
      if (search.trim()) params.set('search', search.trim());
      if (dateFrom) params.set('dateFrom', dateFrom);
      if (dateTo) params.set('dateTo', dateTo);
      const res = await fetch(`/api/prescriptions?${params}`, { credentials: 'include' });
      const data = await res.json() as any;
      if (data.success) {
        setPrescriptions(data.data?.prescriptions || []);
        setPagination(p => ({ ...p, total: data.data?.pagination?.total || 0, pages: data.data?.pagination?.pages || 1 }));
      }
    } catch (e) { console.error(e); }
    finally { setLoading(false); }
  };

  const resetFilters = () => { setFilterStatus(''); setSearch(''); setDateFrom(''); setDateTo(''); setPagination(p => ({ ...p, page: 1 })); };
  const hasFilters = filterStatus || search || dateFrom || dateTo;

  const statusColor = (s: string) => {
    const map: Record<string, string> = {
      pending: 'bg-yellow-100 text-yellow-800',
      quoted: 'bg-blue-100 text-blue-800',
      accepted: 'bg-green-100 text-green-800',
      rejected: 'bg-red-100 text-red-800',
      expired: 'bg-gray-100 text-gray-600',
    };
    return map[s] || 'bg-gray-100 text-gray-800';
  };

  const statusLabel = (s: string) => s.charAt(0).toUpperCase() + s.slice(1);
  const fmt = (d: string) => new Date(d).toLocaleDateString();

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
            <h1 className="text-2xl font-semibold text-gray-800">Prescriptions</h1>
          </div>
        </header>

        <main className="flex-1 overflow-y-auto p-6">
          {/* Stats */}
          <div className="grid grid-cols-2 md:grid-cols-4 gap-4 mb-6">
            {[
              { label: 'Total', value: pagination.total, color: 'bg-blue-500', emoji: '📋' },
              { label: 'Pending', value: prescriptions.filter(p => p.status === 'pending').length, color: 'bg-yellow-500', emoji: '⏳' },
              { label: 'Quoted', value: prescriptions.filter(p => p.status === 'quoted').length, color: 'bg-blue-400', emoji: '💬' },
              { label: 'Accepted', value: prescriptions.filter(p => p.status === 'accepted').length, color: 'bg-green-500', emoji: '✅' },
            ].map(s => (
              <div key={s.label} className="bg-white rounded-xl shadow-sm p-5 border border-gray-100 flex items-center justify-between">
                <div>
                  <p className="text-sm text-gray-500">{s.label}</p>
                  <p className="text-2xl font-bold text-gray-800">{s.value}</p>
                </div>
                <div className={`${s.color} w-11 h-11 rounded-full flex items-center justify-center text-xl`}>{s.emoji}</div>
              </div>
            ))}
          </div>

          {/* Filters toolbar */}
          <div className="mb-4 flex flex-wrap items-center gap-3">
            {/* Status dropdown */}
            <select value={filterStatus} onChange={e => { setFilterStatus(e.target.value); setPagination(p => ({ ...p, page: 1 })); }}
              className="px-4 py-2 rounded-lg border border-gray-200 bg-white text-sm text-gray-700 font-medium focus:outline-none focus:ring-2 focus:ring-green-400">
              {['', 'pending', 'quoted', 'accepted', 'rejected', 'expired'].map(s => (
                <option key={s} value={s}>{s === '' ? 'All Status' : statusLabel(s)}</option>
              ))}
            </select>

            {/* Date range */}
            <div className="flex items-center gap-2">
              <input type="date" value={dateFrom} onChange={e => { setDateFrom(e.target.value); setPagination(p => ({ ...p, page: 1 })); }}
                className="px-3 py-2 rounded-lg border border-gray-200 bg-white text-sm text-gray-700 focus:outline-none focus:ring-2 focus:ring-green-400" />
              <span className="text-gray-400 text-sm">to</span>
              <input type="date" value={dateTo} onChange={e => { setDateTo(e.target.value); setPagination(p => ({ ...p, page: 1 })); }}
                className="px-3 py-2 rounded-lg border border-gray-200 bg-white text-sm text-gray-700 focus:outline-none focus:ring-2 focus:ring-green-400" />
            </div>

            {/* Clear */}
            {hasFilters && (
              <button onClick={resetFilters} className="px-3 py-2 rounded-lg border border-gray-200 bg-white text-sm text-red-500 hover:bg-red-50 font-medium">✕ Clear</button>
            )}

            {/* Search — right */}
            <div className="relative ml-auto">
              <svg className="absolute left-3 top-1/2 -translate-y-1/2 w-4 h-4 text-gray-400" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M21 21l-4.35-4.35M17 11A6 6 0 1 1 5 11a6 6 0 0 1 12 0z" />
              </svg>
              <input type="text" placeholder="Search patient name..."
                value={search} onChange={e => { setSearch(e.target.value); setPagination(p => ({ ...p, page: 1 })); }}
                className="pl-9 pr-4 py-2 rounded-lg border border-gray-200 bg-white text-sm text-gray-700 focus:outline-none focus:ring-2 focus:ring-green-400 w-56" />
            </div>
          </div>

          <div className="bg-white rounded-xl shadow-sm border border-gray-100 overflow-x-auto">
            {loading ? (
              <div className="p-8 text-center text-gray-500">Loading prescriptions...</div>
            ) : prescriptions.length === 0 ? (
              <div className="p-8 text-center text-gray-500">No prescriptions found</div>
            ) : (
              <table className="w-full">
                <thead>
                  <tr className="border-b border-gray-200 bg-gray-50">
                    {['ID', 'Patient', 'Phone', 'Prescription', 'Delivery Address', 'Quotes', 'Status', 'Date', 'Actions'].map(h => (
                      <th key={h} className="text-left py-4 px-5 text-sm font-semibold text-gray-600 whitespace-nowrap">{h}</th>
                    ))}
                  </tr>
                </thead>
                <tbody>
                  {prescriptions.map(p => (
                    <tr key={p._id} className="border-b border-gray-100 hover:bg-gray-50 transition-colors">
                      <td className="py-4 px-5 text-sm text-gray-500 font-mono">{p._id.slice(-6).toUpperCase()}</td>
                      <td className="py-4 px-5">
                        <div className="flex items-center gap-2">
                          <div className="w-8 h-8 rounded-full bg-green-100 flex items-center justify-center text-green-700 font-bold text-sm flex-shrink-0">
                            {p.patientName.charAt(0).toUpperCase()}
                          </div>
                          <span className="font-medium text-gray-800 whitespace-nowrap">{p.patientName}</span>
                        </div>
                      </td>
                      <td className="py-4 px-5 text-gray-600 text-sm whitespace-nowrap">{p.patientPhone || '—'}</td>
                      <td className="py-4 px-5">
                        {p.imageUrl ? (
                          <img src={p.imageUrl} alt="Rx" className="w-12 h-12 object-cover rounded-lg border border-gray-200 cursor-pointer" onClick={() => setSelected(p)} />
                        ) : p.medicines.length > 0 ? (
                          <span className="text-xs bg-green-50 text-green-700 px-2 py-1 rounded-full font-medium">
                            💊 {p.medicines.length} medicine{p.medicines.length > 1 ? 's' : ''}
                          </span>
                        ) : (
                          <span className="text-gray-400 text-sm">—</span>
                        )}
                      </td>
                      <td className="py-4 px-5 text-sm text-gray-600 max-w-[180px] truncate">{p.deliveryAddress || '—'}</td>
                      <td className="py-4 px-5">
                        <div className="flex flex-col gap-0.5">
                          <span className="text-sm font-medium text-gray-800">{p.quotesCount} total</span>
                          {p.acceptedQuotes > 0 && <span className="text-xs text-green-600">✓ {p.acceptedQuotes} accepted</span>}
                          {p.rejectedQuotes > 0 && <span className="text-xs text-red-500">✗ {p.rejectedQuotes} rejected</span>}
                        </div>
                      </td>
                      <td className="py-4 px-5">
                        <span className={`px-3 py-1 rounded-full text-xs font-medium ${statusColor(p.status)}`}>{statusLabel(p.status)}</span>
                      </td>
                      <td className="py-4 px-5 text-sm text-gray-600 whitespace-nowrap">{fmt(p.createdAt)}</td>
                      <td className="py-4 px-5">
                        <button onClick={() => setSelected(p)} className="text-green-600 hover:text-green-700 text-sm font-medium">View</button>
                      </td>
                    </tr>
                  ))}
                </tbody>
              </table>
            )}
            {/* Pagination */}
            <div className="flex items-center justify-between px-6 py-4 border-t border-gray-200">
              <div className="text-sm text-gray-600">Total: <span className="font-medium">{pagination.total}</span> prescriptions</div>
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
      {selected && (
        <div className="fixed inset-0 z-50 flex items-center justify-center bg-black/50 p-4">
          <div className="bg-white rounded-2xl shadow-2xl w-full max-w-2xl max-h-[90vh] overflow-y-auto">
            <div className="flex items-center justify-between px-6 py-4 border-b border-gray-200 sticky top-0 bg-white z-10">
              <div>
                <h2 className="text-xl font-semibold text-gray-800">Prescription Details</h2>
                <p className="text-sm text-gray-500">#{selected._id.slice(-6).toUpperCase()}</p>
              </div>
              <div className="flex items-center gap-3">
                <span className={`px-3 py-1 rounded-full text-xs font-medium ${statusColor(selected.status)}`}>{statusLabel(selected.status)}</span>
                <button onClick={() => setSelected(null)} className="text-gray-400 hover:text-gray-600">
                  <svg className="w-6 h-6" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                    <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M6 18L18 6M6 6l12 12" />
                  </svg>
                </button>
              </div>
            </div>

            <div className="p-6 space-y-5">
              {/* Patient */}
              <div className="bg-gray-50 rounded-xl p-4">
                <h3 className="text-sm font-semibold text-gray-500 mb-3">👤 Patient</h3>
                <div className="flex items-center gap-3">
                  <div className="w-12 h-12 rounded-full bg-green-100 flex items-center justify-center text-green-700 font-bold text-lg">
                    {selected.patientName.charAt(0).toUpperCase()}
                  </div>
                  <div>
                    <p className="font-semibold text-gray-800">{selected.patientName}</p>
                    <p className="text-sm text-gray-500">{selected.patientEmail || '—'}</p>
                    <p className="text-sm text-gray-500">{selected.patientPhone || '—'}</p>
                  </div>
                </div>
              </div>

              {/* Delivery Address */}
              {selected.deliveryAddress && (
                <div className="bg-gray-50 rounded-xl p-4">
                  <h3 className="text-sm font-semibold text-gray-500 mb-2">📍 Delivery Address</h3>
                  <p className="text-gray-800">{selected.deliveryAddress}</p>
                </div>
              )}

              {/* Prescription Image */}
              {selected.imageUrl && (
                <div className="bg-gray-50 rounded-xl p-4">
                  <h3 className="text-sm font-semibold text-gray-500 mb-3">📋 Prescription Image</h3>
                  <img src={selected.imageUrl} alt="Prescription" className="w-full max-h-72 object-contain rounded-xl border border-gray-200" />
                </div>
              )}

              {/* Medicines */}
              {selected.medicines.length > 0 && (
                <div className="bg-gray-50 rounded-xl p-4">
                  <h3 className="text-sm font-semibold text-gray-500 mb-3">💊 Requested Medicines</h3>
                  <div className="space-y-2">
                    {selected.medicines.map((m, i) => (
                      <div key={i} className="flex items-center justify-between bg-white rounded-lg px-4 py-2 border border-gray-100">
                        <span className="text-sm font-medium text-gray-800">{m.name}</span>
                        <span className="text-sm text-gray-500 bg-green-50 px-2 py-0.5 rounded-full">Qty: {m.quantity}</span>
                      </div>
                    ))}
                  </div>
                </div>
              )}

              {/* Quote summary */}
              <div className="bg-gray-50 rounded-xl p-4">
                <h3 className="text-sm font-semibold text-gray-500 mb-3">📜 Quote Summary</h3>
                <div className="grid grid-cols-3 gap-3 text-center">
                  <div className="bg-white rounded-lg p-3 border border-gray-100">
                    <p className="text-2xl font-bold text-gray-800">{selected.quotesCount}</p>
                    <p className="text-xs text-gray-500">Total Quotes</p>
                  </div>
                  <div className="bg-white rounded-lg p-3 border border-green-100">
                    <p className="text-2xl font-bold text-green-600">{selected.acceptedQuotes}</p>
                    <p className="text-xs text-gray-500">Accepted</p>
                  </div>
                  <div className="bg-white rounded-lg p-3 border border-red-100">
                    <p className="text-2xl font-bold text-red-500">{selected.rejectedQuotes}</p>
                    <p className="text-xs text-gray-500">Rejected</p>
                  </div>
                </div>
              </div>

              {/* Quote History */}
              {selected.quoteHistory?.length > 0 && (
                <div className="bg-gray-50 rounded-xl p-4">
                  <h3 className="text-sm font-semibold text-gray-500 mb-3">🏥 Quote History ({selected.quoteHistory.length})</h3>
                  <div className="space-y-3">
                    {selected.quoteHistory.map((q, i) => (
                      <div key={i} className={`rounded-xl border p-4 ${
                        q.status === 'accepted' ? 'border-green-200 bg-green-50' :
                        q.status === 'rejected' ? 'border-red-200 bg-red-50' :
                        'border-gray-200 bg-white'
                      }`}>
                        <div className="flex items-start justify-between mb-2">
                          <div className="flex items-center gap-2">
                            <span className="text-sm font-bold text-gray-800">#{i + 1} {q.pharmacyName}</span>
                            <span className={`px-2 py-0.5 rounded-full text-xs font-medium ${
                              q.status === 'accepted' ? 'bg-green-100 text-green-700' :
                              q.status === 'rejected' ? 'bg-red-100 text-red-700' :
                              q.status === 'pending' ? 'bg-yellow-100 text-yellow-700' :
                              'bg-gray-100 text-gray-600'
                            }`}>
                              {q.status.charAt(0).toUpperCase() + q.status.slice(1)}
                            </span>
                          </div>
                          <span className="text-xs text-gray-400">{new Date(q.createdAt).toLocaleString()}</span>
                        </div>

                        {/* Rejection details */}
                        {q.status === 'rejected' && (
                          <div className={`mt-2 rounded-lg px-3 py-2 flex items-start gap-2 ${
                            q.rejectedBy === 'pharmacy' ? 'bg-red-100' : 'bg-orange-100'
                          }`}>
                            <span className="text-base">{q.rejectedBy === 'pharmacy' ? '🏥' : '👤'}</span>
                            <div>
                              <p className={`text-xs font-semibold ${
                                q.rejectedBy === 'pharmacy' ? 'text-red-700' : 'text-orange-700'
                              }`}>
                                Rejected by {q.rejectedBy === 'pharmacy' ? 'Pharmacy' : 'Patient'}
                              </p>
                              {q.rejectionReason ? (
                                <p className="text-xs text-red-600 mt-0.5">
                                  <span className="font-medium">Reason:</span> {q.rejectionReason}
                                </p>
                              ) : (
                                <p className="text-xs text-orange-600 mt-0.5">Patient cancelled the quote</p>
                              )}
                            </div>
                          </div>
                        )}

                        {/* Accepted quote items */}
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

                        {/* Pending quote amount */}
                        {q.status === 'pending' && q.totalAmount > 0 && (
                          <p className="text-sm text-gray-600 mt-1">Quote: <span className="font-medium">{q.totalAmount} MRO</span></p>
                        )}
                      </div>
                    ))}
                  </div>
                </div>
              )}

              {/* Dates */}
              <div className="bg-gray-50 rounded-xl p-4">
                <h3 className="text-sm font-semibold text-gray-500 mb-3">📅 Timeline</h3>
                <div className="grid grid-cols-2 gap-3">
                  <div>
                    <p className="text-xs text-gray-500">Created</p>
                    <p className="text-sm font-medium text-gray-800">{new Date(selected.createdAt).toLocaleString()}</p>
                  </div>
                  <div>
                    <p className="text-xs text-gray-500">Expires</p>
                    <p className="text-sm font-medium text-gray-800">{new Date(selected.expiresAt).toLocaleString()}</p>
                  </div>
                </div>
              </div>
            </div>

            <div className="px-6 pb-6">
              <button onClick={() => setSelected(null)} className="w-full py-2.5 bg-gray-100 hover:bg-gray-200 text-gray-700 font-medium rounded-xl transition-colors">
                Close
              </button>
            </div>
          </div>
        </div>
      )}
    </div>
  );
}
