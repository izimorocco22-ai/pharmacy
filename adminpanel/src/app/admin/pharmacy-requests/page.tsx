'use client';

import { useState, useEffect } from 'react';
import Sidebar from '@/components/admin/Sidebar';

interface PharmacyRequest {
  _id: string;
  pharmacyName: string;
  licenseNumber: string;
  licenseImageUrl?: string;
  idProofUrl?: string;
  address: string;
  location: { coordinates: [number, number] };
  approvalStatus: string;
  adminNote: string;
  createdAt: string;
  userId: {
    fullName: string;
    email: string;
    phone: string;
    createdAt: string;
  };
}

export default function PharmacyRequestsPage() {
  const [sidebarOpen, setSidebarOpen] = useState(true);
  const [requests, setRequests] = useState<PharmacyRequest[]>([]);
  const [loading, setLoading] = useState(true);
  const [activeTab, setActiveTab] = useState<'pending' | 'approved' | 'rejected'>('pending');
  const [selectedRequest, setSelectedRequest] = useState<PharmacyRequest | null>(null);
  const [showMapModal, setShowMapModal] = useState(false);
  const [showRejectModal, setShowRejectModal] = useState(false);
  const [rejectNote, setRejectNote] = useState('');
  const [actionLoading, setActionLoading] = useState(false);

  useEffect(() => { fetchRequests(); }, [activeTab]);

  const fetchRequests = async () => {
    setLoading(true);
    try {
      const res = await fetch(`/api/admin/pharmacy-requests?status=${activeTab}`);
      const data = await res.json();
      if (data.success) setRequests(data.data?.requests || []);
    } catch (e) {
      console.error(e);
    } finally {
      setLoading(false);
    }
  };

  const handleApprove = async (id: string) => {
    setActionLoading(true);
    try {
      await fetch(`/api/admin/pharmacy-requests/${id}/approve`, { method: 'POST' });
      setSelectedRequest(null);
      fetchRequests();
    } finally {
      setActionLoading(false);
    }
  };

  const handleReject = async () => {
    if (!selectedRequest) return;
    setActionLoading(true);
    try {
      await fetch(`/api/admin/pharmacy-requests/${selectedRequest._id}/reject`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ note: rejectNote }),
      });
      setShowRejectModal(false);
      setSelectedRequest(null);
      setRejectNote('');
      fetchRequests();
    } finally {
      setActionLoading(false);
    }
  };

  const getMapUrl = (req: PharmacyRequest) => {
    const [lng, lat] = req.location?.coordinates || [0, 0];
    return `https://www.openstreetmap.org/export/embed.html?bbox=${lng - 0.01},${lat - 0.01},${lng + 0.01},${lat + 0.01}&layer=mapnik&marker=${lat},${lng}`;
  };

  const statusBadge = (status: string) => {
    const map: Record<string, string> = {
      pending: 'bg-yellow-100 text-yellow-800',
      approved: 'bg-green-100 text-green-800',
      rejected: 'bg-red-100 text-red-800',
    };
    return map[status] || 'bg-gray-100 text-gray-800';
  };

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
            <h1 className="ml-4 text-2xl font-semibold text-gray-800">Pharmacy Requests</h1>
          </div>
        </header>

        <main className="flex-1 overflow-y-auto p-6">
          {/* Tabs */}
          <div className="flex space-x-2 mb-6">
            {(['pending', 'approved', 'rejected'] as const).map(tab => (
              <button key={tab} onClick={() => setActiveTab(tab)}
                className={`px-5 py-2 rounded-lg text-sm font-medium capitalize transition-colors ${activeTab === tab ? 'bg-blue-600 text-white' : 'bg-white text-gray-600 border border-gray-200 hover:bg-gray-50'}`}>
                {tab}
              </button>
            ))}
          </div>

          {/* Table */}
          <div className="bg-white rounded-xl shadow-sm border border-gray-100">
            {loading ? (
              <div className="p-10 text-center text-gray-500">Loading...</div>
            ) : requests.length === 0 ? (
              <div className="p-10 text-center text-gray-500">No {activeTab} requests</div>
            ) : (
              <div className="overflow-x-auto">
                <table className="w-full">
                  <thead>
                    <tr className="border-b border-gray-200 bg-gray-50">
                      <th className="text-left py-4 px-6 text-sm font-semibold text-gray-600">Pharmacy</th>
                      <th className="text-left py-4 px-6 text-sm font-semibold text-gray-600">Owner</th>
                      <th className="text-left py-4 px-6 text-sm font-semibold text-gray-600">Contact</th>
                      <th className="text-left py-4 px-6 text-sm font-semibold text-gray-600">License</th>
                      <th className="text-left py-4 px-6 text-sm font-semibold text-gray-600">Address</th>
                      <th className="text-left py-4 px-6 text-sm font-semibold text-gray-600">Status</th>
                      <th className="text-left py-4 px-6 text-sm font-semibold text-gray-600">Date</th>
                      <th className="text-left py-4 px-6 text-sm font-semibold text-gray-600">Actions</th>
                    </tr>
                  </thead>
                  <tbody>
                    {requests.map(req => (
                      <tr key={req._id} className="border-b border-gray-100 hover:bg-gray-50">
                        <td className="py-4 px-6 font-medium text-gray-800">{req.pharmacyName}</td>
                        <td className="py-4 px-6 text-gray-600">{req.userId?.fullName}</td>
                        <td className="py-4 px-6 text-gray-600">
                          <div>{req.userId?.email}</div>
                          <div className="text-xs text-gray-400">{req.userId?.phone}</div>
                        </td>
                        <td className="py-4 px-6 text-gray-600">{req.licenseNumber}</td>
                        <td className="py-4 px-6 text-gray-600 max-w-xs truncate">{req.address}</td>
                        <td className="py-4 px-6">
                          <span className={`px-3 py-1 rounded-full text-xs font-medium capitalize ${statusBadge(req.approvalStatus)}`}>
                            {req.approvalStatus}
                          </span>
                        </td>
                        <td className="py-4 px-6 text-sm text-gray-500">
                          {new Date(req.createdAt).toLocaleDateString()}
                        </td>
                        <td className="py-4 px-6">
                          <div className="flex space-x-2">
                            <button onClick={() => { setSelectedRequest(req); setShowMapModal(true); }}
                              className="px-3 py-1 text-xs bg-blue-50 text-blue-600 rounded-lg hover:bg-blue-100">
                              📍 Map
                            </button>
                            {req.approvalStatus === 'pending' && (
                              <>
                                <button onClick={() => handleApprove(req._id)}
                                  className="px-3 py-1 text-xs bg-green-50 text-green-600 rounded-lg hover:bg-green-100">
                                  ✓ Approve
                                </button>
                                <button onClick={() => { setSelectedRequest(req); setShowRejectModal(true); }}
                                  className="px-3 py-1 text-xs bg-red-50 text-red-600 rounded-lg hover:bg-red-100">
                                  ✕ Reject
                                </button>
                              </>
                            )}
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

      {/* Map Modal */}
      {showMapModal && selectedRequest && (
        <div className="fixed inset-0 bg-black/50 flex items-center justify-center z-50 p-4">
          <div className="bg-white rounded-2xl shadow-xl w-full max-w-2xl overflow-hidden">
            <div className="flex items-center justify-between p-5 border-b">
              <div>
                <h2 className="text-lg font-semibold text-gray-800">{selectedRequest.pharmacyName}</h2>
                <p className="text-sm text-gray-500 mt-0.5">{selectedRequest.address}</p>
              </div>
              <button onClick={() => setShowMapModal(false)} className="text-gray-400 hover:text-gray-600 text-2xl">×</button>
            </div>
            <div className="p-5 grid grid-cols-2 gap-4 text-sm border-b">
              <div><span className="text-gray-500">Owner:</span> <span className="font-medium">{selectedRequest.userId?.fullName}</span></div>
              <div><span className="text-gray-500">Email:</span> <span className="font-medium">{selectedRequest.userId?.email}</span></div>
              <div><span className="text-gray-500">Phone:</span> <span className="font-medium">{selectedRequest.userId?.phone}</span></div>
              <div><span className="text-gray-500">License:</span> <span className="font-medium">{selectedRequest.licenseNumber}</span></div>
              <div className="col-span-2"><span className="text-gray-500">Coordinates:</span> <span className="font-medium">{selectedRequest.location?.coordinates?.[1]?.toFixed(5)}, {selectedRequest.location?.coordinates?.[0]?.toFixed(5)}</span></div>
              <div className="col-span-2">
                <span className="text-gray-500 block mb-2">Documents:</span>
                <div className="flex space-x-4">
                  {selectedRequest.licenseImageUrl ? (
                    <a href={selectedRequest.licenseImageUrl} target="_blank" rel="noopener noreferrer" className="block">
                      <img src={selectedRequest.licenseImageUrl} alt="Pharmacy license" className="h-24 w-36 object-cover rounded-lg border border-gray-200 hover:opacity-80" />
                      <span className="text-xs text-blue-600 mt-1 block text-center">Pharmacy License ↗</span>
                    </a>
                  ) : (
                    <span className="text-xs text-gray-400 italic">No license image</span>
                  )}
                  {selectedRequest.idProofUrl ? (
                    <a href={selectedRequest.idProofUrl} target="_blank" rel="noopener noreferrer" className="block">
                      <img src={selectedRequest.idProofUrl} alt="Identity proof" className="h-24 w-36 object-cover rounded-lg border border-gray-200 hover:opacity-80" />
                      <span className="text-xs text-blue-600 mt-1 block text-center">Identity Proof ↗</span>
                    </a>
                  ) : (
                    <span className="text-xs text-gray-400 italic">No identity proof</span>
                  )}
                </div>
              </div>
            </div>
            <iframe src={getMapUrl(selectedRequest)} className="w-full h-72 border-0" loading="lazy" />
            {selectedRequest.approvalStatus === 'pending' && (
              <div className="flex space-x-3 p-5 border-t">
                <button onClick={() => { handleApprove(selectedRequest._id); setShowMapModal(false); }}
                  disabled={actionLoading}
                  className="flex-1 py-2.5 bg-green-600 text-white rounded-lg hover:bg-green-700 font-medium disabled:opacity-60">
                  ✓ Approve
                </button>
                <button onClick={() => { setShowMapModal(false); setShowRejectModal(true); }}
                  className="flex-1 py-2.5 bg-red-600 text-white rounded-lg hover:bg-red-700 font-medium">
                  ✕ Reject
                </button>
              </div>
            )}
          </div>
        </div>
      )}

      {/* Reject Modal */}
      {showRejectModal && selectedRequest && (
        <div className="fixed inset-0 bg-black/50 flex items-center justify-center z-50 p-4">
          <div className="bg-white rounded-2xl shadow-xl w-full max-w-md p-6">
            <h2 className="text-lg font-semibold text-gray-800 mb-1">Reject Request</h2>
            <p className="text-sm text-gray-500 mb-4">Rejecting <strong>{selectedRequest.pharmacyName}</strong>. Add a note for the pharmacy owner.</p>
            <textarea
              value={rejectNote}
              onChange={e => setRejectNote(e.target.value)}
              placeholder="Reason for rejection (e.g. Invalid license number, incomplete information...)"
              rows={4}
              className="w-full border border-gray-300 rounded-lg px-4 py-3 text-sm focus:outline-none focus:ring-2 focus:ring-red-400 resize-none"
            />
            <div className="flex space-x-3 mt-4">
              <button onClick={() => { setShowRejectModal(false); setRejectNote(''); }}
                className="flex-1 py-2.5 border border-gray-300 text-gray-700 rounded-lg hover:bg-gray-50 font-medium">
                Cancel
              </button>
              <button onClick={handleReject} disabled={actionLoading || !rejectNote.trim()}
                className="flex-1 py-2.5 bg-red-600 text-white rounded-lg hover:bg-red-700 font-medium disabled:opacity-60">
                {actionLoading ? 'Rejecting...' : 'Confirm Reject'}
              </button>
            </div>
          </div>
        </div>
      )}
    </div>
  );
}
