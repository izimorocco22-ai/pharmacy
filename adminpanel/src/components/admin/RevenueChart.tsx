'use client';

import { useState, useEffect } from 'react';

interface DailyStat { _id: string; orders: number; revenue: number; }
interface StatusStat { _id: string; count: number; }

const STATUS_COLORS: Record<string, string> = {
  delivered: 'bg-emerald-500',
  in_transit: 'bg-blue-500',
  preparing: 'bg-yellow-400',
  confirmed: 'bg-purple-500',
  assigned: 'bg-indigo-500',
  picked_up: 'bg-cyan-500',
  ready: 'bg-lime-500',
  cancelled: 'bg-red-400',
  pending: 'bg-orange-400',
};

export default function RevenueChart() {
  const [data, setData] = useState<DailyStat[]>([]);
  const [statusData, setStatusData] = useState<StatusStat[]>([]);
  const [view, setView] = useState<'revenue' | 'orders'>('revenue');
  const [loading, setLoading] = useState(true);
  const [totals, setTotals] = useState({ revenue: 0, orders: 0, avgRevenue: 0 });

  useEffect(() => {
    fetch('/api/analytics')
      .then(r => r.json())
      .then(json => {
        if (json.success) {
          const stats: DailyStat[] = json.data.charts.last30Stats;
          setData(stats);
          setStatusData(json.data.charts.ordersByStatus || []);
          const totalRev = stats.reduce((s, d) => s + d.revenue, 0);
          const totalOrd = stats.reduce((s, d) => s + d.orders, 0);
          setTotals({ revenue: totalRev, orders: totalOrd, avgRevenue: stats.length ? Math.round(totalRev / stats.length) : 0 });
        }
      })
      .catch(console.error)
      .finally(() => setLoading(false));
  }, []);

  const maxVal = Math.max(...data.map(d => d[view]), 1);
  const totalOrders = statusData.reduce((s, d) => s + d.count, 0);

  return (
    <div className="bg-white rounded-xl border border-gray-200 p-6 flex flex-col gap-5">
      {/* Header */}
      <div className="flex items-start justify-between">
        <div>
          <h2 className="text-base font-bold text-gray-900">Performance Overview</h2>
          <p className="text-xs text-gray-400 mt-0.5">Last 30 days</p>
        </div>
        <div className="flex gap-1.5">
          {(['revenue', 'orders'] as const).map(v => (
            <button key={v} onClick={() => setView(v)}
              className={`text-xs px-3 py-1.5 rounded-lg font-semibold transition-colors ${view === v ? 'bg-green-600 text-white' : 'bg-gray-100 text-gray-500 hover:bg-gray-200'}`}>
              {v.charAt(0).toUpperCase() + v.slice(1)}
            </button>
          ))}
        </div>
      </div>

      {/* Summary pills */}
      <div className="grid grid-cols-3 gap-3">
        {[
          { label: '30d Revenue', value: `${totals.revenue.toLocaleString()} MRO`, color: 'text-emerald-600' },
          { label: '30d Orders', value: totals.orders.toLocaleString(), color: 'text-blue-600' },
          { label: 'Avg/Day', value: `${totals.avgRevenue.toLocaleString()} MRO`, color: 'text-purple-600' },
        ].map(s => (
          <div key={s.label} className="bg-gray-50 rounded-lg px-3 py-2.5 text-center">
            <p className={`text-base font-bold ${s.color}`}>{s.value}</p>
            <p className="text-xs text-gray-400 mt-0.5">{s.label}</p>
          </div>
        ))}
      </div>

      {/* Bar chart */}
      {loading ? (
        <div className="flex items-center justify-center h-40">
          <div className="animate-spin w-8 h-8 border-4 border-green-500 border-t-transparent rounded-full" />
        </div>
      ) : data.length === 0 ? (
        <div className="flex items-center justify-center h-40 text-gray-400 text-sm">No data yet</div>
      ) : (
        <div>
          <div className="flex items-end gap-0.5" style={{ height: '160px' }}>
            {data.map((d, i) => {
              const pct = (d[view] / maxVal) * 100;
              return (
                <div key={i} className="flex-1 group relative flex flex-col justify-end" style={{ height: '100%' }}>
                  <div className="absolute bottom-full left-1/2 -translate-x-1/2 mb-1.5 bg-gray-900 text-white text-xs px-2 py-1 rounded-md opacity-0 group-hover:opacity-100 whitespace-nowrap z-10 pointer-events-none shadow-lg">
                    {d._id}<br />{view === 'revenue' ? `${d.revenue.toLocaleString()} MRO` : `${d.orders} orders`}
                  </div>
                  <div
                    className={`w-full rounded-t-sm transition-all duration-300 ${view === 'revenue' ? 'bg-green-500 group-hover:bg-green-600' : 'bg-blue-500 group-hover:bg-blue-600'}`}
                    style={{ height: `${Math.max(pct, 3)}%` }}
                  />
                </div>
              );
            })}
          </div>
          <div className="flex justify-between text-xs text-gray-400 mt-2 px-0.5">
            <span>{data[0]?._id}</span>
            <span>{data[data.length - 1]?._id}</span>
          </div>
        </div>
      )}

      {/* Order status breakdown */}
      {statusData.length > 0 && (
        <div>
          <p className="text-xs font-semibold text-gray-500 uppercase tracking-wide mb-3">Order Status Breakdown</p>
          <div className="space-y-2">
            {statusData.slice(0, 5).map(s => {
              const pct = totalOrders ? Math.round((s.count / totalOrders) * 100) : 0;
              const color = STATUS_COLORS[s._id] || 'bg-gray-400';
              return (
                <div key={s._id}>
                  <div className="flex justify-between text-xs mb-1">
                    <span className="text-gray-600 capitalize font-medium">{s._id.replace(/_/g, ' ')}</span>
                    <span className="text-gray-500">{s.count} <span className="text-gray-400">({pct}%)</span></span>
                  </div>
                  <div className="w-full bg-gray-100 rounded-full h-1.5">
                    <div className={`${color} h-1.5 rounded-full`} style={{ width: `${pct}%` }} />
                  </div>
                </div>
              );
            })}
          </div>
        </div>
      )}
    </div>
  );
}
