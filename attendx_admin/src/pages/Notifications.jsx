import { useEffect, useState } from 'react'
import { Send, Users, BookOpen, User, Clock } from 'lucide-react'
import api from '../services/api'

const TARGET_TYPES = [
  { value: 'all',     label: 'All Students',   icon: Users },
  { value: 'course',  label: 'By Course',       icon: BookOpen },
  { value: 'student', label: 'Specific Student', icon: User },
]

export default function Notifications() {
  const [courses,  setCourses]  = useState([])
  const [students, setStudents] = useState([])
  const [sent,     setSent]     = useState([])
  const [loadingSent, setLoadingSent] = useState(true)

  const [targetType, setTargetType] = useState('all')
  const [targetId,   setTargetId]   = useState('')
  const [content,    setContent]    = useState('')
  const [sending,    setSending]    = useState(false)
  const [flash,      setFlash]      = useState(null)

  useEffect(() => {
    Promise.all([
      api.get('/admin/courses'),
      api.get('/admin/users'),
      api.get('/messages/sent'),
    ]).then(([cr, ur, sr]) => {
      setCourses(cr.data.data)
      setStudents(ur.data.data.filter(u => u.role === 'student'))
      setSent(sr.data.data)
      setLoadingSent(false)
    })
  }, [])

  async function handleSend(e) {
    e.preventDefault()
    if (!content.trim()) return
    if ((targetType === 'course' || targetType === 'student') && !targetId) {
      setFlash({ type: 'error', text: 'Please select a target.' })
      return
    }

    setSending(true)
    setFlash(null)
    try {
      await api.post('/messages/send', {
        content: content.trim(),
        targetType,
        targetId: targetType === 'all' ? undefined : targetId,
      })

      const sr = await api.get('/messages/sent')
      setSent(sr.data.data)
      setContent('')
      setTargetId('')
      setFlash({ type: 'success', text: 'Message sent successfully.' })
    } catch (err) {
      setFlash({ type: 'error', text: err.response?.data?.error || 'Failed to send.' })
    } finally {
      setSending(false)
    }
  }

  const targetLabel = (msg) => {
    if (msg.targetType === 'all') return 'All Students'
    return msg.targetLabel || msg.targetId
  }

  return (
    <div className="space-y-6">
      <div>
        <h2 className="text-xl font-bold text-slate-800">Notifications & Announcements</h2>
        <p className="text-slate-500 text-sm mt-1">Send messages to students via the app inbox and real-time socket</p>
      </div>

      {/* Compose */}
      <div className="bg-white rounded-2xl p-6 shadow-sm border border-slate-100">
        <h3 className="font-semibold text-slate-700 mb-4">Compose Message</h3>
        <form onSubmit={handleSend} className="space-y-4">

          {/* Target type selector */}
          <div className="grid grid-cols-3 gap-3">
            {TARGET_TYPES.map(({ value, label, icon: Icon }) => (
              <button
                key={value}
                type="button"
                onClick={() => { setTargetType(value); setTargetId('') }}
                className={`flex items-center gap-2 px-4 py-2.5 rounded-xl border-2 text-sm font-medium transition-colors ${
                  targetType === value
                    ? 'border-blue-500 bg-blue-50 text-blue-700'
                    : 'border-slate-200 text-slate-500 hover:border-slate-300'
                }`}
              >
                <Icon size={16} /> {label}
              </button>
            ))}
          </div>

          {/* Target selector */}
          {targetType === 'course' && (
            <select
              value={targetId}
              onChange={e => setTargetId(e.target.value)}
              className="input w-full"
              required
            >
              <option value="">— Select course —</option>
              {courses.map(c => (
                <option key={c.id} value={c.id}>{c.code} – {c.name}</option>
              ))}
            </select>
          )}

          {targetType === 'student' && (
            <select
              value={targetId}
              onChange={e => setTargetId(e.target.value)}
              className="input w-full"
              required
            >
              <option value="">— Select student —</option>
              {students.map(s => (
                <option key={s.id} value={s.id}>{s.fullName} ({s.regNumber || s.email})</option>
              ))}
            </select>
          )}

          {/* Message body */}
          <textarea
            value={content}
            onChange={e => setContent(e.target.value)}
            placeholder="Write your announcement or message here…"
            rows={4}
            required
            className="input resize-none w-full"
          />

          {flash && (
            <p className={`text-sm ${flash.type === 'error' ? 'text-red-600' : 'text-emerald-600'}`}>
              {flash.text}
            </p>
          )}

          <button
            type="submit"
            disabled={sending}
            className="btn-primary flex items-center gap-2"
          >
            <Send size={16} />
            {sending ? 'Sending…' : 'Send Message'}
          </button>
        </form>
      </div>

      {/* Sent history */}
      <div className="bg-white rounded-2xl shadow-sm border border-slate-100 overflow-hidden">
        <div className="px-6 py-4 border-b border-slate-100">
          <h3 className="font-semibold text-slate-700">Sent Messages</h3>
        </div>
        {loadingSent ? (
          <div className="flex justify-center py-10 text-slate-400">Loading…</div>
        ) : sent.length === 0 ? (
          <div className="text-center py-10 text-slate-400">No messages sent yet</div>
        ) : (
          <table className="w-full">
            <thead>
              <tr className="border-b border-slate-100">
                <th className="th">To</th>
                <th className="th">Message</th>
                <th className="th">Read</th>
                <th className="th">Sent At</th>
              </tr>
            </thead>
            <tbody>
              {sent.map(m => (
                <tr key={m.id} className="border-b border-slate-50 hover:bg-slate-50 transition-colors">
                  <td className="td">
                    <span className="badge badge-blue capitalize">{m.targetType === 'all' ? 'All' : m.targetType}</span>
                    <span className="ml-2 text-slate-500 text-xs">{targetLabel(m)}</span>
                  </td>
                  <td className="td text-slate-700 max-w-xs truncate">{m.content}</td>
                  <td className="td text-slate-500 text-sm">{m.readCount}</td>
                  <td className="td text-slate-400 text-xs whitespace-nowrap">
                    <span className="flex items-center gap-1">
                      <Clock size={12} />
                      {new Date(m.sentAt).toLocaleString()}
                    </span>
                  </td>
                </tr>
              ))}
            </tbody>
          </table>
        )}
      </div>
    </div>
  )
}
