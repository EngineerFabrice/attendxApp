import { useEffect, useState } from 'react'
import { MessageSquare, Send, X, Users, User, Loader2 } from 'lucide-react'
import api from '../services/api'

export default function SendMessageModal({ onClose, defaultTarget = null }) {
  const [courses, setCourses]     = useState([])
  const [students, setStudents]   = useState([])
  const [targetType, setTargetType] = useState(defaultTarget?.type || 'course')
  const [targetId, setTargetId]   = useState(defaultTarget?.id || '')
  const [content, setContent]     = useState('')
  const [sending, setSending]     = useState(false)
  const [sent, setSent]           = useState(false)
  const [error, setError]         = useState(null)
  const [sentMessages, setSentMessages] = useState([])
  const [loadingSent, setLoadingSent]   = useState(true)

  useEffect(() => {
    Promise.all([
      api.get('/lecturer/courses'),
      api.get('/lecturer/students'),
      api.get('/messages/sent'),
    ]).then(([c, s, m]) => {
      setCourses(c.data.data || [])
      setStudents(s.data.data || [])
      setSentMessages(m.data.data || [])
      if (!targetId && (c.data.data || []).length) {
        setTargetId(c.data.data[0].id)
      }
      setLoadingSent(false)
    }).catch(() => setLoadingSent(false))
  }, [])

  async function handleSend() {
    if (!content.trim()) return
    setSending(true)
    setError(null)
    try {
      const payload = { content: content.trim(), targetType }
      if (targetType !== 'all') payload.targetId = targetId
      const r = await api.post('/messages/send', payload)
      setSentMessages(prev => [r.data.data, ...prev])
      setContent('')
      setSent(true)
      setTimeout(() => setSent(false), 2500)
    } catch (e) {
      setError(e.response?.data?.error || 'Failed to send message')
    } finally {
      setSending(false)
    }
  }

  const targetOptions = targetType === 'course' ? courses : students

  return (
    <div className="fixed inset-0 bg-black/50 z-50 flex items-center justify-center p-4">
      <div className="bg-white rounded-2xl shadow-2xl w-full max-w-2xl flex flex-col max-h-[90vh]">

        {/* Header */}
        <div className="flex items-center justify-between px-6 py-4 border-b border-slate-100">
          <div className="flex items-center gap-2">
            <MessageSquare size={20} className="text-blue-600" />
            <h3 className="font-bold text-slate-800 text-lg">Send Message</h3>
          </div>
          <button onClick={onClose} className="p-1.5 text-slate-400 hover:text-slate-600 rounded-lg hover:bg-slate-100">
            <X size={18} />
          </button>
        </div>

        <div className="flex flex-1 overflow-hidden">
          {/* Compose panel */}
          <div className="flex-1 p-6 space-y-4 border-r border-slate-100">
            <p className="text-slate-500 text-sm">Send a real-time message to a course group or individual student.</p>

            {/* Target type */}
            <div className="flex gap-2">
              {[
                { value: 'course',  label: 'Course Group', Icon: Users },
                { value: 'student', label: 'One Student',  Icon: User  },
              ].map(({ value, label, Icon }) => (
                <button
                  key={value}
                  onClick={() => { setTargetType(value); setTargetId(targetOptions[0]?.id || '') }}
                  className={`flex-1 flex items-center justify-center gap-2 py-2.5 rounded-xl border text-sm font-medium transition-colors
                    ${targetType === value
                      ? 'bg-blue-600 border-blue-600 text-white'
                      : 'border-slate-200 text-slate-600 hover:bg-slate-50'}`}
                >
                  <Icon size={15} /> {label}
                </button>
              ))}
            </div>

            {/* Target selector */}
            <div>
              <label className="text-slate-600 text-sm mb-1.5 block">
                {targetType === 'course' ? 'Select Course' : 'Select Student'}
              </label>
              <select
                value={targetId}
                onChange={e => setTargetId(e.target.value)}
                className="input"
              >
                {targetOptions.map(t => (
                  <option key={t.id} value={t.id}>
                    {t.code ? `${t.code} — ${t.name}` : `${t.fullName} (${t.regNumber || t.email})`}
                  </option>
                ))}
              </select>
            </div>

            {/* Message content */}
            <div>
              <label className="text-slate-600 text-sm mb-1.5 block">Message</label>
              <textarea
                value={content}
                onChange={e => setContent(e.target.value)}
                onKeyDown={e => { if (e.key === 'Enter' && (e.ctrlKey || e.metaKey)) handleSend() }}
                placeholder="Type your message here… (Ctrl+Enter to send)"
                rows={4}
                className="input resize-none"
                maxLength={500}
              />
              <p className="text-right text-xs text-slate-400 mt-1">{content.length}/500</p>
            </div>

            {error && (
              <p className="text-sm text-red-600 bg-red-50 border border-red-200 rounded-xl px-4 py-2">{error}</p>
            )}

            <button
              onClick={handleSend}
              disabled={sending || !content.trim()}
              className="w-full btn-primary flex items-center justify-center gap-2 disabled:opacity-50"
            >
              {sending ? <><Loader2 size={16} className="animate-spin" /> Sending…</> :
               sent    ? '✅ Sent!' :
               <><Send size={15} /> Send Message</>}
            </button>
          </div>

          {/* Sent messages history */}
          <div className="w-64 flex flex-col">
            <p className="px-4 py-3 text-xs font-semibold text-slate-500 uppercase tracking-wide border-b border-slate-100">
              Recently Sent
            </p>
            <div className="flex-1 overflow-y-auto">
              {loadingSent ? (
                <div className="flex justify-center py-8"><Loader2 size={20} className="animate-spin text-slate-300" /></div>
              ) : sentMessages.length === 0 ? (
                <p className="text-center py-8 text-slate-400 text-sm">No messages yet</p>
              ) : sentMessages.map(m => (
                <div key={m.id} className="px-4 py-3 border-b border-slate-50 hover:bg-slate-50">
                  <div className="flex items-center justify-between mb-1">
                    <span className={`text-xs font-medium px-1.5 py-0.5 rounded-full
                      ${m.targetType === 'course' ? 'bg-blue-100 text-blue-700' : 'bg-purple-100 text-purple-700'}`}>
                      {m.targetLabel}
                    </span>
                    <span className="text-xs text-slate-400">{m.readCount} read</span>
                  </div>
                  <p className="text-xs text-slate-600 line-clamp-2">{m.content}</p>
                  <p className="text-xs text-slate-400 mt-1">
                    {new Date(m.sentAt).toLocaleTimeString([], { hour: '2-digit', minute: '2-digit' })}
                  </p>
                </div>
              ))}
            </div>
          </div>
        </div>
      </div>
    </div>
  )
}
