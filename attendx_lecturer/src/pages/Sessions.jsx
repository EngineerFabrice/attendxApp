import { useEffect, useState } from 'react'
import { Plus, Radio, Clock, CheckCircle, ExternalLink, MessageSquare, X } from 'lucide-react'
import { useNavigate } from 'react-router-dom'
import api from '../services/api'

function SendMessageModal({ course, onClose }) {
  const [content, setContent] = useState('')
  const [sending, setSending] = useState(false)
  const [sent, setSent] = useState(false)

  async function handleSend(e) {
    e.preventDefault()
    if (!content.trim()) return
    setSending(true)
    try {
      await api.post('/messages/send', {
        targetType: 'course',
        targetId: course.id,
        content: content.trim(),
      })
      setSent(true)
      setTimeout(onClose, 1200)
    } catch (err) {
      alert(err.response?.data?.error || 'Failed to send message')
    } finally {
      setSending(false)
    }
  }

  return (
    <div className="fixed inset-0 bg-black/50 z-50 flex items-center justify-center p-4">
      <div className="bg-white rounded-2xl p-6 w-full max-w-md shadow-2xl">
        <div className="flex items-center justify-between mb-4">
          <h3 className="font-bold text-slate-800 text-lg">
            Announce to {course.name}
          </h3>
          <button onClick={onClose} className="p-1 hover:bg-slate-100 rounded-lg">
            <X size={18} className="text-slate-500" />
          </button>
        </div>
        {sent ? (
          <div className="py-8 text-center text-emerald-600 font-medium">
            ✓ Announcement sent to all enrolled students!
          </div>
        ) : (
          <form onSubmit={handleSend} className="space-y-4">
            <textarea
              value={content}
              onChange={e => setContent(e.target.value)}
              placeholder="Type your announcement…"
              rows={4}
              className="input resize-none"
              required
            />
            <p className="text-xs text-slate-400">
              This message will be delivered to all students enrolled in <strong>{course.code}</strong>.
            </p>
            <div className="flex gap-3">
              <button type="button" onClick={onClose} className="flex-1 btn-secondary">Cancel</button>
              <button type="submit" disabled={sending || !content.trim()} className="flex-1 btn-primary flex items-center justify-center gap-2">
                <MessageSquare size={15} />
                {sending ? 'Sending…' : 'Send'}
              </button>
            </div>
          </form>
        )}
      </div>
    </div>
  )
}

function StartModal({ onClose, onStart, loading }) {
  const [courses, setCourses] = useState([])
  const [classrooms, setClassrooms] = useState([])
  const [form, setForm] = useState({ courseId: '', classroomId: '' })

  useEffect(() => {
    Promise.all([api.get('/lecturer/courses'), api.get('/lecturer/classrooms')]).then(([c, r]) => {
      setCourses(c.data.data); setClassrooms(r.data.data)
      setForm({ courseId: c.data.data[0]?.id || '', classroomId: r.data.data[0]?.id || '' })
    })
  }, [])

  return (
    <div className="fixed inset-0 bg-black/50 z-50 flex items-center justify-center p-4">
      <div className="bg-white rounded-2xl p-6 w-full max-w-md shadow-2xl">
        <h3 className="font-bold text-slate-800 text-lg mb-5">Start New Session</h3>
        <div className="space-y-3">
          <div>
            <label className="text-slate-600 text-sm mb-1.5 block">Course</label>
            <select value={form.courseId} onChange={e => setForm(f => ({ ...f, courseId: e.target.value }))} className="input">
              {courses.map(c => <option key={c.id} value={c.id}>{c.code} — {c.name}</option>)}
            </select>
          </div>
          <div>
            <label className="text-slate-600 text-sm mb-1.5 block">Classroom</label>
            <select value={form.classroomId} onChange={e => setForm(f => ({ ...f, classroomId: e.target.value }))} className="input">
              {classrooms.map(r => <option key={r.id} value={r.id}>{r.name} (radius: {r.radiusM}m)</option>)}
            </select>
          </div>
          <p className="text-xs text-slate-400 pt-1">GPS geofence will activate automatically when the session starts.</p>
        </div>
        <div className="flex gap-3 mt-5">
          <button onClick={onClose} className="flex-1 btn-secondary">Cancel</button>
          <button onClick={() => onStart(form)} disabled={loading || !form.courseId || !form.classroomId} className="flex-1 btn-primary flex items-center justify-center gap-2">
            <Radio size={16} /> {loading ? 'Starting…' : 'Start Session'}
          </button>
        </div>
      </div>
    </div>
  )
}

export default function Sessions() {
  const [sessions, setSessions] = useState([])
  const [loading, setLoading] = useState(true)
  const [starting, setStarting] = useState(false)
  const [showModal, setShowModal] = useState(false)
  const [announceTarget, setAnnounceTarget] = useState(null)
  const [error, setError] = useState(null)
  const navigate = useNavigate()

  useEffect(() => {
    api.get('/lecturer/sessions')
      .then(r => { setSessions(r.data.data); setLoading(false) })
      .catch(err => { setError(err.response?.data?.error || 'Request failed'); setLoading(false) })
  }, [])

  async function handleStart(form) {
    setStarting(true)
    try {
      const r = await api.post('/lecturer/sessions/start', form)
      setSessions(s => [r.data.data, ...s])
      setShowModal(false)
      navigate(`/sessions/${r.data.data.id}/live`)
    } catch (err) {
      setError(err.response?.data?.error || 'Request failed')
    } finally {
      setStarting(false)
    }
  }

  async function handleClose(id) {
    if (!confirm('Close this session? Students will no longer be able to check in.')) return
    try {
      await api.post(`/lecturer/sessions/${id}/close`)
      setSessions(s => s.map(sess => sess.id === id ? { ...sess, status: 'closed' } : sess))
    } catch (err) {
      setError(err.response?.data?.error || 'Request failed')
    }
  }

  if (loading) return <div className="flex justify-center py-20 text-slate-400">Loading…</div>

  const active = sessions.find(s => s.status === 'active')

  return (
    <div className="space-y-5">
      {error && (
        <div className="flex items-center justify-between bg-red-50 border border-red-200 text-red-700 px-4 py-3 rounded-xl">
          <span className="text-sm">{error}</span>
          <button onClick={() => setError(null)} className="ml-4 text-red-500 hover:text-red-700 font-bold text-lg leading-none">&times;</button>
        </div>
      )}
      <div className="flex items-center justify-between">
        <div>
          <h2 className="text-xl font-bold text-slate-800">Sessions</h2>
          <p className="text-slate-500 text-sm mt-1">{sessions.length} sessions total</p>
        </div>
        <button onClick={() => setShowModal(true)} disabled={!!active} className="btn-primary flex items-center gap-2">
          <Plus size={16} /> Start Session
        </button>
      </div>

      {/* Active session banner */}
      {active && (
        <div className="bg-emerald-50 border border-emerald-200 rounded-2xl p-5 flex items-center gap-4">
          <div className="w-3 h-3 bg-emerald-500 rounded-full animate-pulse" />
          <div className="flex-1">
            <p className="font-semibold text-emerald-800">{active.course.name} — LIVE</p>
            <p className="text-emerald-600 text-sm">Code: <span className="font-mono font-bold">{active.code}</span> · {active.classroom.name}</p>
          </div>
          <button onClick={() => navigate(`/sessions/${active.id}/live`)} className="flex items-center gap-1.5 text-emerald-700 font-medium text-sm hover:underline">
            <ExternalLink size={14} /> Monitor
          </button>
          <button onClick={() => handleClose(active.id)} className="btn-danger text-xs py-1.5 px-3">End Session</button>
        </div>
      )}

      {/* Session history */}
      <div className="bg-white rounded-2xl shadow-sm border border-slate-100 overflow-hidden">
        <table className="w-full">
          <thead>
            <tr className="border-b border-slate-100">
              <th className="th">Course</th>
              <th className="th">Code</th>
              <th className="th">Classroom</th>
              <th className="th">Date</th>
              <th className="th">Attendance</th>
              <th className="th">Status</th>
              <th className="th">Actions</th>
            </tr>
          </thead>
          <tbody>
            {sessions.map(s => (
              <tr key={s.id} className="border-b border-slate-50 hover:bg-slate-50 transition-colors">
                <td className="td font-medium text-slate-800">{s.course.name}</td>
                <td className="td font-mono text-slate-500">{s.code || s.sessionCode}</td>
                <td className="td text-slate-500">{s.classroom.name}</td>
                <td className="td text-slate-500">{new Date(s.startedAt).toLocaleDateString()}</td>
                <td className="td">
                  <span className="font-semibold text-slate-800">{s.presentCount}</span>
                  {s.lateCount > 0 && <span className="text-amber-500 text-xs ml-1">+{s.lateCount}L</span>}
                  <span className="text-slate-400">/{s.totalStudents}</span>
                </td>
                <td className="td">
                  {s.status === 'active'
                    ? <span className="badge badge-green flex items-center gap-1 w-fit"><span className="w-1.5 h-1.5 bg-emerald-500 rounded-full" />Live</span>
                    : <span className="badge badge-gray flex items-center gap-1 w-fit"><CheckCircle size={11} />Closed</span>}
                </td>
                <td className="td">
                  <div className="flex items-center gap-1">
                    {s.status === 'active' && (
                      <button onClick={() => navigate(`/sessions/${s.id}/live`)} className="p-1.5 text-emerald-600 hover:bg-emerald-50 rounded-lg transition-colors" title="Monitor">
                        <ExternalLink size={15} />
                      </button>
                    )}
                    <button
                      onClick={() => setAnnounceTarget(s.course)}
                      className="p-1.5 text-blue-600 hover:bg-blue-50 rounded-lg transition-colors"
                      title="Send announcement"
                    >
                      <MessageSquare size={15} />
                    </button>
                  </div>
                </td>
              </tr>
            ))}
          </tbody>
        </table>
        {sessions.length === 0 && <p className="text-center py-10 text-slate-400">No sessions yet. Start one above.</p>}
      </div>

      {showModal && <StartModal onClose={() => setShowModal(false)} onStart={handleStart} loading={starting} />}
      {announceTarget && <SendMessageModal course={announceTarget} onClose={() => setAnnounceTarget(null)} />}
    </div>
  )
}
