import { useEffect, useState } from 'react'
import { Plus, AlertTriangle, Search, MessageSquare, X } from 'lucide-react'
import api from '../services/api'

function DirectMessageModal({ student, onClose }) {
  const [content, setContent] = useState('')
  const [sending, setSending] = useState(false)
  const [sent, setSent] = useState(false)

  async function handleSend(e) {
    e.preventDefault()
    if (!content.trim()) return
    setSending(true)
    try {
      await api.post('/messages/send', {
        targetType: 'student',
        targetId: student.id,
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
            Message {student.fullName}
          </h3>
          <button onClick={onClose} className="p-1 hover:bg-slate-100 rounded-lg">
            <X size={18} className="text-slate-500" />
          </button>
        </div>
        {sent ? (
          <div className="py-8 text-center text-emerald-600 font-medium">
            ✓ Message sent!
          </div>
        ) : (
          <form onSubmit={handleSend} className="space-y-4">
            <div className="flex items-center gap-2 p-3 bg-slate-50 rounded-xl text-sm text-slate-600">
              <div className="w-7 h-7 rounded-full bg-blue-100 flex items-center justify-center text-blue-700 font-bold text-xs">
                {student.fullName[0]}
              </div>
              <span>{student.fullName} · {student.regNumber}</span>
            </div>
            <textarea
              value={content}
              onChange={e => setContent(e.target.value)}
              placeholder="Type your message…"
              rows={4}
              className="input resize-none"
              required
            />
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

function Modal({ onClose, onSubmit, loading, courses }) {
  const [form, setForm] = useState({ fullName: '', email: '', regNumber: '', course: courses[0]?.code || '' })
  const set = k => e => setForm(f => ({ ...f, [k]: e.target.value }))

  return (
    <div className="fixed inset-0 bg-black/50 z-50 flex items-center justify-center p-4">
      <div className="bg-white rounded-2xl p-6 w-full max-w-md shadow-2xl">
        <h3 className="font-bold text-slate-800 text-lg mb-5">Add Student</h3>
        <form onSubmit={e => { e.preventDefault(); onSubmit(form) }} className="space-y-3">
          <input required value={form.fullName} onChange={set('fullName')} placeholder="Full name" className="input" />
          <input required value={form.regNumber} onChange={set('regNumber')} placeholder="Registration number" className="input" />
          <input required type="email" value={form.email} onChange={set('email')} placeholder="Email" className="input" />
          <select value={form.course} onChange={set('course')} className="input">
            {courses.map(c => <option key={c.id} value={c.code}>{c.code} — {c.name}</option>)}
          </select>
          <div className="flex gap-3 pt-2">
            <button type="button" onClick={onClose} className="flex-1 btn-secondary">Cancel</button>
            <button type="submit" disabled={loading} className="flex-1 btn-primary">{loading ? 'Saving…' : 'Add Student'}</button>
          </div>
        </form>
      </div>
    </div>
  )
}

export default function Students() {
  const [students, setStudents] = useState([])
  const [courses, setCourses] = useState([])
  const [loading, setLoading] = useState(true)
  const [saving, setSaving] = useState(false)
  const [showModal, setShowModal] = useState(false)
  const [messageTarget, setMessageTarget] = useState(null)
  const [search, setSearch] = useState('')
  const [showAtRisk, setShowAtRisk] = useState(false)
  const [error, setError] = useState(null)

  useEffect(() => {
    Promise.all([
      api.get('/lecturer/students'),
      api.get('/lecturer/courses'),
    ])
      .then(([studRes, courseRes]) => {
        setStudents(studRes.data.data)
        setCourses(courseRes.data.data || [])
        setLoading(false)
      })
      .catch(err => { setError(err.response?.data?.error || 'Request failed'); setLoading(false) })
  }, [])

  async function handleAdd(form) {
    setSaving(true)
    try {
      const r = await api.post('/lecturer/students', form)
      setStudents(s => [...s, r.data.data])
      setShowModal(false)
    } catch (err) {
      setError(err.response?.data?.error || 'Request failed')
    } finally {
      setSaving(false)
    }
  }

  const filtered = students.filter(s => {
    const matchSearch = s.fullName.toLowerCase().includes(search.toLowerCase()) || s.regNumber.includes(search)
    const matchRisk = showAtRisk ? s.attendanceRate < 75 : true
    return matchSearch && matchRisk
  })

  if (loading) return <div className="flex justify-center py-20 text-slate-400">Loading…</div>

  const atRiskCount = students.filter(s => s.attendanceRate < 75).length

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
          <h2 className="text-xl font-bold text-slate-800">Students</h2>
          <p className="text-slate-500 text-sm mt-1">{students.length} enrolled · {atRiskCount} at risk</p>
        </div>
        <div className="flex gap-2">
          <button
            onClick={() => setShowAtRisk(s => !s)}
            className={`flex items-center gap-2 px-4 py-2.5 rounded-xl border text-sm font-medium transition-colors ${showAtRisk ? 'bg-orange-100 border-orange-300 text-orange-700' : 'btn-secondary'}`}
          >
            <AlertTriangle size={15} /> At-Risk Only
          </button>
          <button onClick={() => setShowModal(true)} className="btn-primary flex items-center gap-2">
            <Plus size={16} /> Add Student
          </button>
        </div>
      </div>

      <div className="relative max-w-xs">
        <Search size={16} className="absolute left-3 top-1/2 -translate-y-1/2 text-slate-400" />
        <input value={search} onChange={e => setSearch(e.target.value)} placeholder="Search students…" className="input pl-9" />
      </div>

      <div className="bg-white rounded-2xl shadow-sm border border-slate-100 overflow-hidden">
        <table className="w-full">
          <thead>
            <tr className="border-b border-slate-100">
              <th className="th">Student</th>
              <th className="th">Reg. Number</th>
              <th className="th">Course</th>
              <th className="th">Attendance Rate</th>
              <th className="th">Status</th>
              <th className="th">Actions</th>
            </tr>
          </thead>
          <tbody>
            {filtered.map(s => (
              <tr key={s.id} className="border-b border-slate-50 hover:bg-slate-50 transition-colors">
                <td className="td">
                  <div className="flex items-center gap-3">
                    <div className="w-8 h-8 rounded-full bg-blue-100 flex items-center justify-center text-blue-700 font-bold text-sm">
                      {s.fullName[0]}
                    </div>
                    <div>
                      <p className="font-medium text-slate-800">{s.fullName}</p>
                      <p className="text-slate-400 text-xs">{s.email}</p>
                    </div>
                  </div>
                </td>
                <td className="td font-mono text-slate-500">{s.regNumber}</td>
                <td className="td"><span className="badge badge-blue">{s.course}</span></td>
                <td className="td">
                  <div className="flex items-center gap-2">
                    <div className="flex-1 h-2 bg-slate-100 rounded-full overflow-hidden max-w-24">
                      <div className={`h-full rounded-full ${s.attendanceRate >= 75 ? 'bg-emerald-500' : 'bg-red-500'}`} style={{ width: `${s.attendanceRate}%` }} />
                    </div>
                    <span className={`font-semibold text-sm ${s.attendanceRate >= 75 ? 'text-emerald-600' : 'text-red-600'}`}>{s.attendanceRate}%</span>
                  </div>
                </td>
                <td className="td">
                  {s.attendanceRate < 75
                    ? <span className="badge badge-red flex items-center gap-1 w-fit"><AlertTriangle size={11} />At Risk</span>
                    : <span className="badge badge-green">Good Standing</span>}
                </td>
                <td className="td">
                  <button
                    onClick={() => setMessageTarget(s)}
                    className="p-1.5 text-blue-600 hover:bg-blue-50 rounded-lg transition-colors"
                    title="Send message"
                  >
                    <MessageSquare size={15} />
                  </button>
                </td>
              </tr>
            ))}
          </tbody>
        </table>
        {filtered.length === 0 && <p className="text-center py-10 text-slate-400">No students found</p>}
      </div>

      {showModal && <Modal onClose={() => setShowModal(false)} onSubmit={handleAdd} loading={saving} courses={courses} />}
      {messageTarget && <DirectMessageModal student={messageTarget} onClose={() => setMessageTarget(null)} />}
    </div>
  )
}
