import { useEffect, useState, useCallback } from 'react'
import { CheckCircle, XCircle, Clock, RefreshCw, Loader2 } from 'lucide-react'
import api from '../services/api'

function ReviewModal({ appeal, onClose, onReviewed }) {
  const [action,  setAction]  = useState('approved')
  const [note,    setNote]    = useState('')
  const [loading, setLoading] = useState(false)
  const [error,   setError]   = useState(null)

  async function handleSubmit() {
    setLoading(true)
    setError(null)
    try {
      await api.post(`/appeals/${appeal.id}/review`, { action, note: note.trim() || undefined })
      onReviewed(appeal.id, action)
      onClose()
    } catch (err) {
      setError(err.response?.data?.error || 'Review failed')
    } finally {
      setLoading(false)
    }
  }

  return (
    <div className="fixed inset-0 bg-black/50 z-50 flex items-center justify-center p-4">
      <div className="bg-white rounded-2xl p-6 w-full max-w-md shadow-2xl">
        <h3 className="font-bold text-slate-800 text-lg mb-1">Review Appeal</h3>
        <p className="text-slate-500 text-sm mb-5">
          {appeal.student.fullName} · {appeal.courseName} ·{' '}
          {new Date(appeal.sessionDate).toLocaleDateString()}
        </p>

        <div className="bg-slate-50 rounded-xl p-4 mb-5">
          <p className="text-xs font-semibold text-slate-500 uppercase mb-1">Student's Reason</p>
          <p className="text-sm text-slate-700 leading-relaxed">{appeal.reason}</p>
        </div>

        <div className="flex gap-3 mb-4">
          {['approved', 'rejected'].map(a => (
            <button
              key={a}
              onClick={() => setAction(a)}
              className={`flex-1 flex items-center justify-center gap-2 py-2.5 rounded-xl border-2 text-sm font-semibold transition-colors ${
                action === a
                  ? a === 'approved'
                    ? 'border-emerald-500 bg-emerald-50 text-emerald-700'
                    : 'border-red-500 bg-red-50 text-red-700'
                  : 'border-slate-200 text-slate-500 hover:border-slate-300'
              }`}
            >
              {a === 'approved' ? <CheckCircle size={16} /> : <XCircle size={16} />}
              {a === 'approved' ? 'Approve' : 'Reject'}
            </button>
          ))}
        </div>

        <textarea
          value={note}
          onChange={e => setNote(e.target.value)}
          placeholder="Optional note to student…"
          rows={3}
          className="input resize-none w-full mb-4 text-sm"
        />

        {error && <p className="text-red-600 text-sm mb-3">{error}</p>}

        <div className="flex gap-3">
          <button onClick={onClose} className="flex-1 btn-secondary">Cancel</button>
          <button
            onClick={handleSubmit}
            disabled={loading}
            className={`flex-1 flex items-center justify-center gap-2 ${
              action === 'approved'
                ? 'btn-primary'
                : 'bg-red-500 hover:bg-red-600 text-white font-semibold py-2 px-4 rounded-xl transition-colors'
            }`}
          >
            {loading
              ? <><Loader2 size={15} className="animate-spin" /> Submitting…</>
              : 'Confirm'}
          </button>
        </div>
      </div>
    </div>
  )
}

const STATUS_CFG = {
  pending:  { label: 'Pending',  color: 'text-orange-600 bg-orange-50 border-orange-200', icon: <Clock size={12} /> },
  approved: { label: 'Approved', color: 'text-emerald-600 bg-emerald-50 border-emerald-200', icon: <CheckCircle size={12} /> },
  rejected: { label: 'Rejected', color: 'text-red-600 bg-red-50 border-red-200', icon: <XCircle size={12} /> },
}

export default function Appeals() {
  const [appeals,   setAppeals]   = useState([])
  const [loading,   setLoading]   = useState(true)
  const [filter,    setFilter]    = useState('pending')
  const [reviewing, setReviewing] = useState(null)
  const [error,     setError]     = useState(null)

  const load = useCallback(async () => {
    setLoading(true)
    setError(null)
    try {
      const r = await api.get('/appeals', { params: { status: filter } })
      setAppeals(r.data.data)
    } catch (err) {
      setError(err.response?.data?.error || 'Failed to load appeals')
    } finally {
      setLoading(false)
    }
  }, [filter])

  useEffect(() => { load() }, [load])

  function handleReviewed(id) {
    setAppeals(prev => prev.filter(a => a.id !== id))
  }

  return (
    <div className="space-y-5">
      <div className="flex items-center justify-between">
        <div>
          <h2 className="text-xl font-bold text-slate-800">Attendance Appeals</h2>
          <p className="text-slate-500 text-sm mt-1">Review and override student attendance disputes</p>
        </div>
        <button onClick={load} disabled={loading} className="btn-secondary flex items-center gap-2">
          <RefreshCw size={15} className={loading ? 'animate-spin' : ''} /> Refresh
        </button>
      </div>

      <div className="flex gap-2">
        {['pending', 'approved', 'rejected'].map(s => (
          <button
            key={s}
            onClick={() => setFilter(s)}
            className={`px-4 py-1.5 rounded-full text-sm font-medium capitalize transition-colors border ${
              filter === s ? STATUS_CFG[s].color : 'text-slate-500 border-slate-200 hover:border-slate-300'
            }`}
          >
            {s}
          </button>
        ))}
      </div>

      {error && (
        <div className="bg-red-50 border border-red-200 text-red-700 px-4 py-3 rounded-xl text-sm">{error}</div>
      )}

      {loading ? (
        <div className="flex justify-center py-16 text-slate-400">Loading…</div>
      ) : appeals.length === 0 ? (
        <div className="bg-white rounded-2xl p-12 text-center shadow-sm border border-slate-100">
          <CheckCircle size={40} className="mx-auto mb-3 text-slate-200" />
          <p className="text-slate-400 font-medium">No {filter} appeals</p>
        </div>
      ) : (
        <div className="space-y-3">
          {appeals.map(appeal => (
            <div key={appeal.id} className="bg-white rounded-2xl p-5 shadow-sm border border-slate-100">
              <div className="flex items-start gap-4">
                <div className="w-10 h-10 rounded-full bg-blue-100 flex items-center justify-center text-blue-700 font-bold text-sm shrink-0">
                  {appeal.student.fullName[0]}
                </div>
                <div className="flex-1 min-w-0">
                  <div className="flex items-center gap-2 flex-wrap">
                    <span className="font-semibold text-slate-800 text-sm">{appeal.student.fullName}</span>
                    <span className="text-slate-400 text-xs">{appeal.student.regNumber}</span>
                    <span className={`inline-flex items-center gap-1 px-2 py-0.5 rounded-full text-xs font-semibold border ${STATUS_CFG[appeal.status]?.color}`}>
                      {STATUS_CFG[appeal.status]?.icon}
                      {appeal.originalStatus}
                    </span>
                  </div>
                  <p className="text-slate-500 text-xs mt-0.5">
                    {appeal.courseName} · {new Date(appeal.sessionDate).toLocaleDateString()}
                  </p>
                  <p className="text-slate-700 text-sm mt-2 leading-relaxed">{appeal.reason}</p>
                  {appeal.reviewNote && (
                    <p className="text-slate-500 text-xs mt-1 italic">Note: {appeal.reviewNote}</p>
                  )}
                </div>
                <div className="shrink-0">
                  {appeal.status === 'pending' ? (
                    <button onClick={() => setReviewing(appeal)} className="btn-primary text-sm py-1.5 px-4">
                      Review
                    </button>
                  ) : (
                    <span className={`inline-flex items-center gap-1 px-3 py-1.5 rounded-xl text-xs font-semibold border ${STATUS_CFG[appeal.status]?.color}`}>
                      {STATUS_CFG[appeal.status]?.icon}
                      {STATUS_CFG[appeal.status]?.label}
                    </span>
                  )}
                </div>
              </div>
            </div>
          ))}
        </div>
      )}

      {reviewing && (
        <ReviewModal
          appeal={reviewing}
          onClose={() => setReviewing(null)}
          onReviewed={handleReviewed}
        />
      )}
    </div>
  )
}
