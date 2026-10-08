'use client';

import { useState, useEffect } from 'react';
import Sidebar from '@/components/admin/Sidebar';

interface Rider {
  _id: string;
  vehicleType: string;
  vehicleNumber: string;
  licenseNumber: string;
  licenseImageUrl?: string;
  isOnline: boolean;
  isAvailable: boolean;
  rating: number;
  totalDeliveries: number;
  totalEarnings: number;
  walletBalance?: number;
  createdAt: string;
  userId: {
    _id: string;
    fullName: string;
    email: string;
    phone: string;
    profileImage?: string;
    isActive: boolean;
    createdAt: string;
  };
}

interface WalletTxn {
  _id: string;
  type: 'deduct' | 'add' | 'payout';
  amount: number;
  balanceAfter: number;
  note?: string;
  createdAt: string;
}

export default function RidersPage() {
  const [sidebarOpen, setSidebarOpen] = useState(true);
  const [riders, setRiders] = useState<Rider[]>([]);
  const [loading, setLoading] = useState(true);
  const [search, setSearch] = useState('');
  const [selectedRider, setSelectedRider] = useState<Rider | null>(null);

  useEffect(() => { fetchRiders(); }, []);

  const fetchRiders = async () => {
    setLoading(true);
    try {
      const res = await fetch('/api/admin/riders');
      const data = await res.json();
      if (data.success) setRiders(data.data?.riders || []);
    } catch (e) { console.error(e); }
    finally { setLoading(false); }
  };

  // Wallet balance; legacy riders (no walletBalance yet) show lifetime earnings
  const balanceOf = (r: Rider) => r.walletBalance ?? r.totalEarnings ?? 0;

  // Wallet modal
  const [walletRider, setWalletRider] = useState<Rider | null>(null);
  const [walletData, setWalletData] = useState<{ walletBalance: number; transactions: WalletTxn[] } | null>(null);
  const [walletLoading, setWalletLoading] = useState(false);
  const [walletAction, setWalletAction] = useState<'deduct' | 'add'>('deduct');
  const [walletAmount, setWalletAmount] = useState('');
  const [walletNote, setWalletNote] = useState('');
  const [walletSaving, setWalletSaving] = useState(false);
  const [walletError, setWalletError] = useState('');

  const loadWallet = async (riderId: string) => {
    setWalletLoading(true);
    try {
      const res = await fetch(`/api/admin/riders/${riderId}/wallet`);
      const data = await res.json();
      if (data.success) setWalletData(data.data);
      else setWalletError(data.message || 'Failed to load wallet');
    } catch (e) { console.error(e); }
    finally { setWalletLoading(false); }
  };

  const openWallet = (rider: Rider) => {
    setWalletRider(rider);
    setWalletData(null);
    setWalletAction('deduct');
    setWalletAmount('');
    setWalletNote('');
    setWalletError('');
    loadWallet(rider._id);
  };

  const handleWalletSubmit = async (e: React.FormEvent) => {
    e.preventDefault();
    if (!walletRider) return;
    const amount = Number(walletAmount);
    if (!Number.isFinite(amount) || amount <= 0) {
      setWalletError('Enter an amount greater than zero');
      return;
    }
    const verb = walletAction === 'deduct' ? 'Deduct' : 'Add';
    if (!confirm(`${verb} ${amount.toLocaleString()} MRO ${walletAction === 'deduct' ? 'from' : 'to'} ${walletRider.userId?.fullName}'s wallet?`)) return;
    setWalletSaving(true);
    setWalletError('');
    try {
      const res = await fetch(`/api/admin/riders/${walletRider._id}/wallet`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ action: walletAction, amount, note: walletNote }),
      });
      const data = await res.json();
      if (data.success) {
        setWalletAmount('');
        setWalletNote('');
        loadWallet(walletRider._id);
        fetchRiders();
      } else {
        setWalletError(data.message || 'Failed to update wallet');
      }
    } catch (e) { console.error(e); }
    finally { setWalletSaving(false); }
  };

  const filtered = riders.filter(r =>
    r.userId?.fullName?.toLowerCase().includes(search.toLowerCase()) ||
    r.userId?.email?.toLowerCase().includes(search.toLowerCase()) ||
    r.userId?.phone?.includes(search)
  );

  const totalEarnings = riders.reduce((sum, r) => sum + (r.totalEarnings || 0), 0);
  const onlineCount = riders.filter(r => r.isOnline).length;
  const avgRating = riders.length ? (riders.reduce((s, r) => s + r.rating, 0) / riders.length).toFixed(1) : '0.0';

  return (
    <div className="flex h-screen bg-gray-50">
      <Sidebar isOpen={sidebarOpen} />
      <div className="flex-1 flex flex-col overflow-hidden">
        <header className="bg-white shadow-sm">
          <div className="flex items-center justify-between px-6 py-4">
            <div className="flex items-center">
              <button onClick={() => setSidebarOpen(!sidebarOpen)} className="text-gray-500 hover:text-gray-700">
                <svg className="w-6 h-6" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                  <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M4 6h16M4 12h16M4 18h16" />
                </svg>
              </button>
              <h1 className="ml-4 text-2xl font-semibold text-gray-800">Riders Management</h1>
            </div>
          </div>
        </header>

        <main className="flex-1 overflow-y-auto p-6">
          {/* Stats */}
          <div className="grid grid-cols-1 md:grid-cols-4 gap-6 mb-6">
            {[
              { label: 'Total Riders', value: riders.length, icon: '🏍️', color: 'bg-blue-500' },
              { label: 'Online Now', value: onlineCount, icon: '✅', color: 'bg-green-500' },
              { label: 'Avg Rating', value: avgRating, icon: '⭐', color: 'bg-yellow-500' },
              { label: 'Total Earnings', value: `${totalEarnings.toLocaleString()} MRO`, icon: '💰', color: 'bg-purple-500' },
            ].map(stat => (
              <div key={stat.label} className="bg-white rounded-xl shadow-sm p-6 border border-gray-100">
                <div className="flex items-center justify-between">
                  <div>
                    <p className="text-sm text-gray-600 mb-1">{stat.label}</p>
                    <h3 className="text-2xl font-bold text-gray-800">{stat.value}</h3>
                  </div>
                  <div className={`${stat.color} w-12 h-12 rounded-full flex items-center justify-center`}>
                    <span className="text-2xl">{stat.icon}</span>
                  </div>
                </div>
              </div>
            ))}
          </div>

          <div className="bg-white rounded-xl shadow-sm border border-gray-100">
            <div className="p-6 border-b border-gray-200">
              <input type="text" placeholder="Search riders by name, email or phone..."
                value={search} onChange={e => setSearch(e.target.value)}
                className="px-4 py-2 border border-gray-300 rounded-lg focus:outline-none focus:ring-2 focus:ring-blue-500 w-96" />
            </div>

            {loading ? (
              <div className="p-10 text-center text-gray-500">Loading...</div>
            ) : filtered.length === 0 ? (
              <div className="p-10 text-center text-gray-500">No riders found</div>
            ) : (
              <div className="overflow-x-auto">
                <table className="w-full">
                  <thead>
                    <tr className="border-b border-gray-200 bg-gray-50">
                      <th className="text-left py-4 px-6 text-sm font-semibold text-gray-600">Rider</th>
                      <th className="text-left py-4 px-6 text-sm font-semibold text-gray-600">Contact</th>
                      <th className="text-left py-4 px-6 text-sm font-semibold text-gray-600">Vehicle</th>
                      <th className="text-left py-4 px-6 text-sm font-semibold text-gray-600">Deliveries</th>
                      <th className="text-left py-4 px-6 text-sm font-semibold text-gray-600">Earnings</th>
                      <th className="text-left py-4 px-6 text-sm font-semibold text-gray-600">Rating</th>
                      <th className="text-left py-4 px-6 text-sm font-semibold text-gray-600">Status</th>
                      <th className="text-left py-4 px-6 text-sm font-semibold text-gray-600">Actions</th>
                    </tr>
                  </thead>
                  <tbody>
                    {filtered.map(rider => (
                      <tr key={rider._id} className="border-b border-gray-100 hover:bg-gray-50 transition-colors">
                        <td className="py-4 px-6">
                          <div className="flex items-center">
                            {rider.userId?.profileImage ? (
                              <img src={rider.userId.profileImage} className="w-10 h-10 rounded-full object-cover mr-3" />
                            ) : (
                              <div className="w-10 h-10 bg-blue-100 rounded-full flex items-center justify-center text-blue-600 font-semibold mr-3">
                                {rider.userId?.fullName?.charAt(0) || 'R'}
                              </div>
                            )}
                            <span className="font-medium text-gray-800">{rider.userId?.fullName}</span>
                          </div>
                        </td>
                        <td className="py-4 px-6 text-gray-600">
                          <div>{rider.userId?.email}</div>
                          <div className="text-xs text-gray-400">{rider.userId?.phone}</div>
                        </td>
                        <td className="py-4 px-6 text-gray-600 capitalize">
                          <div>{rider.vehicleType}</div>
                          <div className="text-xs text-gray-400">{rider.vehicleNumber || '—'}</div>
                        </td>
                        <td className="py-4 px-6 font-medium text-gray-800">{rider.totalDeliveries}</td>
                        <td className="py-4 px-6">
                          <div className="font-medium text-gray-800">{rider.totalEarnings.toLocaleString()} MRO</div>
                        </td>
                        <td className="py-4 px-6">
                          <div className="flex items-center">
                            <span className="text-yellow-500 mr-1">⭐</span>
                            <span className="font-medium text-gray-800">{rider.rating.toFixed(1)}</span>
                          </div>
                        </td>
                        <td className="py-4 px-6">
                          <span className={`px-3 py-1 rounded-full text-xs font-medium ${rider.isOnline ? 'bg-green-100 text-green-800' : 'bg-gray-100 text-gray-800'}`}>
                            {rider.isOnline ? 'Online' : 'Offline'}
                          </span>
                        </td>
                        <td className="py-4 px-6">
                          <div className="flex space-x-2">
                            <button onClick={() => setSelectedRider(rider)}
                              className="px-3 py-1 text-xs bg-blue-50 text-blue-600 rounded-lg hover:bg-blue-100 font-medium">
                              View More
                            </button>
                            <button onClick={() => openWallet(rider)}
                              className="px-3 py-1 text-xs bg-purple-50 text-purple-600 rounded-lg hover:bg-purple-100 font-medium">
                              👛 Wallet
                            </button>
                          </div>
                        </td>
                      </tr>
                    ))}
                  </tbody>
                </table>
              </div>
            )}
          </div>
        </main>
      </div>

      {/* View More Modal */}
      {selectedRider && (
        <div className="fixed inset-0 bg-black/50 flex items-center justify-center z-50 p-4">
          <div className="bg-white rounded-2xl shadow-xl w-full max-w-lg overflow-hidden">
            <div className="flex items-center justify-between p-5 border-b">
              <h2 className="text-lg font-semibold text-gray-800">Rider Details</h2>
              <button onClick={() => setSelectedRider(null)} className="text-gray-400 hover:text-gray-600 text-2xl">×</button>
            </div>

            <div className="p-5">
              {/* Profile */}
              <div className="flex items-center mb-5">
                {selectedRider.userId?.profileImage ? (
                  <img src={selectedRider.userId.profileImage} className="w-16 h-16 rounded-full object-cover mr-4" />
                ) : (
                  <div className="w-16 h-16 bg-blue-100 rounded-full flex items-center justify-center text-blue-600 text-2xl font-bold mr-4">
                    {selectedRider.userId?.fullName?.charAt(0) || 'R'}
                  </div>
                )}
                <div>
                  <h3 className="text-lg font-semibold text-gray-800">{selectedRider.userId?.fullName}</h3>
                  <p className="text-sm text-gray-500">{selectedRider.userId?.email}</p>
                  <p className="text-sm text-gray-500">{selectedRider.userId?.phone}</p>
                </div>
              </div>

              {/* Stats grid */}
              <div className="grid grid-cols-3 gap-3 mb-5">
                {[
                  { label: 'Total Deliveries', value: selectedRider.totalDeliveries, icon: '📦' },
                  { label: 'Total Earnings', value: `${selectedRider.totalEarnings.toLocaleString()} MRO`, icon: '💰' },
                  { label: 'Wallet Balance', value: `${balanceOf(selectedRider).toLocaleString()} MRO`, icon: '💵' },
                  { label: 'Rating', value: `${selectedRider.rating.toFixed(1)} ⭐`, icon: '⭐' },
                ].map(s => (
                  <div key={s.label} className="bg-gray-50 rounded-xl p-3 text-center border border-gray-100">
                    <div className="text-xl mb-1">{s.icon}</div>
                    <div className="text-lg font-bold text-gray-800">{s.value}</div>
                    <div className="text-xs text-gray-500">{s.label}</div>
                  </div>
                ))}
              </div>

              {/* Details */}
              <div className="space-y-2 text-sm">
                {[
                  { label: 'Vehicle Type', value: selectedRider.vehicleType },
                  { label: 'Vehicle Number', value: selectedRider.vehicleNumber || '—' },
                  { label: 'License Number', value: selectedRider.licenseNumber },
                  { label: 'Status', value: selectedRider.isOnline ? '🟢 Online' : '⚫ Offline' },
                  { label: 'Available', value: selectedRider.isAvailable ? 'Yes' : 'No' },
                  { label: 'Account Active', value: selectedRider.userId?.isActive ? 'Yes' : 'No' },
                  { label: 'Joined', value: new Date(selectedRider.userId?.createdAt).toLocaleDateString() },
                ].map(item => (
                  <div key={item.label} className="flex justify-between py-2 border-b border-gray-100">
                    <span className="text-gray-500">{item.label}</span>
                    <span className="font-medium text-gray-800 capitalize">{item.value}</span>
                  </div>
                ))}
                {selectedRider.licenseImageUrl && (
                  <div className="flex justify-between py-2 border-b border-gray-100">
                    <span className="text-gray-500">License Image</span>
                    <a href={selectedRider.licenseImageUrl} target="_blank" rel="noreferrer"
                      className="text-blue-600 hover:underline font-medium">View Image</a>
                  </div>
                )}
              </div>
            </div>
          </div>
        </div>
      )}

      {/* Wallet Modal */}
      {walletRider && (
        <div className="fixed inset-0 bg-black/50 flex items-center justify-center z-50 p-4">
          <div className="bg-white rounded-2xl shadow-xl w-full max-w-lg max-h-[90vh] flex flex-col overflow-hidden">
            <div className="flex items-center justify-between p-5 border-b">
              <div>
                <h2 className="text-lg font-semibold text-gray-800">Wallet Management</h2>
                <p className="text-sm text-gray-500">{walletRider.userId?.fullName}</p>
              </div>
              <button onClick={() => setWalletRider(null)} className="text-gray-400 hover:text-gray-600 text-2xl">×</button>
            </div>

            <div className="p-5 overflow-y-auto">
              {/* Balance */}
              <div className="bg-purple-50 border border-purple-100 rounded-xl p-4 mb-5 text-center">
                <div className="text-sm text-purple-700 mb-1">Current Wallet Balance</div>
                <div className="text-3xl font-bold text-purple-800">
                  {walletData ? `${walletData.walletBalance.toLocaleString()} MRO` : walletLoading ? '...' : '—'}
                </div>
              </div>

              {/* Deduct / Add form */}
              <form onSubmit={handleWalletSubmit} className="space-y-3 mb-6">
                <div className="grid grid-cols-2 gap-2">
                  {(['deduct', 'add'] as const).map(a => (
                    <button key={a} type="button" onClick={() => setWalletAction(a)}
                      className={`py-2 rounded-lg text-sm font-medium border ${walletAction === a
                        ? a === 'deduct' ? 'bg-red-600 text-white border-red-600' : 'bg-green-600 text-white border-green-600'
                        : 'bg-white text-gray-600 border-gray-300 hover:bg-gray-50'}`}>
                      {a === 'deduct' ? '− Deduct' : '+ Add'}
                    </button>
                  ))}
                </div>
                <input type="number" min="0" step="0.01" placeholder="Amount (MRO)"
                  value={walletAmount} onChange={e => setWalletAmount(e.target.value)}
                  className="w-full px-4 py-2 border border-gray-300 rounded-lg focus:outline-none focus:ring-2 focus:ring-purple-500" />
                <input type="text" maxLength={300} placeholder="Reason / note (optional)"
                  value={walletNote} onChange={e => setWalletNote(e.target.value)}
                  className="w-full px-4 py-2 border border-gray-300 rounded-lg focus:outline-none focus:ring-2 focus:ring-purple-500" />
                {walletError && <p className="text-sm text-red-600">{walletError}</p>}
                <button type="submit" disabled={walletSaving || !walletAmount}
                  className={`w-full py-2 rounded-lg text-white font-medium disabled:opacity-60 ${walletAction === 'deduct' ? 'bg-red-600 hover:bg-red-700' : 'bg-green-600 hover:bg-green-700'}`}>
                  {walletSaving ? 'Saving...' : walletAction === 'deduct' ? 'Deduct from Wallet' : 'Add to Wallet'}
                </button>
              </form>

              {/* History */}
              <h3 className="text-sm font-semibold text-gray-700 mb-2">Wallet History</h3>
              {walletLoading && !walletData ? (
                <p className="text-sm text-gray-500">Loading...</p>
              ) : !walletData?.transactions.length ? (
                <p className="text-sm text-gray-400">No wallet changes yet</p>
              ) : (
                <div className="divide-y divide-gray-100 border border-gray-100 rounded-xl">
                  {walletData.transactions.map(t => (
                    <div key={t._id} className="flex items-center justify-between p-3 text-sm">
                      <div>
                        <div className="font-medium text-gray-800">
                          {t.type === 'deduct' ? 'Deducted' : t.type === 'add' ? 'Added' : 'Paid out'}
                        </div>
                        {t.note && <div className="text-xs text-gray-500">{t.note}</div>}
                        <div className="text-xs text-gray-400">{new Date(t.createdAt).toLocaleString()}</div>
                      </div>
                      <div className="text-right">
                        <div className={`font-semibold ${t.type === 'add' ? 'text-green-600' : 'text-red-600'}`}>
                          {t.type === 'add' ? '+' : '−'}{t.amount.toLocaleString()} MRO
                        </div>
                        <div className="text-xs text-gray-400">Bal: {t.balanceAfter.toLocaleString()} MRO</div>
                      </div>
                    </div>
                  ))}
                </div>
              )}
            </div>
          </div>
        </div>
      )}
    </div>
  );
}
