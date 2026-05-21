import { useEffect, useState } from 'react'
import { Plus, Users, BookOpen, Pencil, Trash2, UserPlus, UserMinus, X } from 'lucide-react'
import api from '../services/api'

const DEPTS = ['Computer Science', 'Mathematics', 'Physics', 'Engineering']

function CourseModal({ initial, lecturers, onClose, onSubmit, loading }) {
  const [form, setForm] = useState(
    initial
      ? { code: initial.code, name: initial.name, credits: initial.credits,
          department: initial.department || 'Computer Science', lecturerId: initial.lecturer?.id || '' }
      : { code: '', name: '', credits: 3, department: 'Computer Science', lecturerId: '' }
  )
  const set = k => e => setForm(f => ({ ...f, [k]: e.target.value }))

  return (
    <div className="fixed inset-0 bg-black/50 z-50 flex items-center justify-center p-4">
      <div className="bg-white rounded-2xl p-6 w-full max-w-md shadow-2xl">
        <h3 className="font-bold text-slate-800 text-lg mb-5">
          {initial ? 'Edit Course' : 'Create Course'}
        </h3>
        <form onSubmit={e => { e.preventDefault(); onSubmit(form) }} className="space-y-3">
          <input required value={form.code} onChange={set('code')} placeholder="Course code (e.g. CS401)" className="input" />
          <input required value={form.name} onChange={set('name')} placeholder="Course name" className="input" />
          <input required type="number" value={form.credits} onChange={set('credits')} placeholder="Credits" min={1} max={6} className="input" />
          <select value={form.department} onChange={set('department')} className="input">
            {DEPTS.map(d => <option key={d}>{d}</option>)}
          </select>
          <select value={form.lecturerId} onChange={set('lecturerId')} className="input">
            <option value="">— Assign lecturer (optional) —</option>
            {lecturers.map(l => <option key={l.id} value={l.id}>{l.fullName}</option>)}
          </select>
          <div className="flex gap-3 pt-2">
            <button type="button" onClick={onClose} className="flex-1 btn-secondary">Cancel</button>
            <button type="submit" disabled={loading} className="flex-1 btn-primary">
              {loading ? 'Saving…' : initial ? 'Save Changes' : 'Create Course'}
            </button>
          </div>
        </form>
      </div>
    </div>
  )
}

function EnrollModal({ course, students, onClose }) {
  const [enrolled, setEnrolled] = useState([])
  const [loading, setLoading]   = useState(true)
  const [search,  setSearch]    = useState('')
  const [busy,    setBusy]      = useState(null)

  useEffect(() => {
    api.get(`/admin/courses/${course.id}/enrollments`).then(r => {
      setEnrolled(r.data.data)
      setLoading(false)
    })
  }, [course.id])

  const enrolledIds = new Set(enrolled.map(e => e.id))

  async function handleEnroll(student) {
    setBusy(student.id)
    try {
      await api.post(`/admin/courses/${course.id}/enrollments`, { studentId: student.id })
      setEnrolled(prev => [...prev, student])
    } finally { setBusy(null) }
  }

  async function handleUnenroll(studentId) {
    setBusy(studentId)
    try {
      await api.delete(`/admin/courses/${course.id}/enrollments/${studentId}`)
      setEnrolled(prev => prev.filter(e => e.id !== studentId))
    } finally { setBusy(null) }
  }

  const available = students.filter(s =>
    !enrolledIds.has(s.id) &&
    (s.fullName.toLowerCase().includes(search.toLowerCase()) ||
     (s.regNumber || '').toLowerCase().includes(search.toLowerCase()))
  )

  return (
    <div className="fixed inset-0 bg-black/50 z-50 flex items-center justify-center p-4">
      <div className="bg-white rounded-2xl p-6 w-full max-w-lg shadow-2xl max-h-[90vh] flex flex-col">
        <div className="flex items-center justify-between mb-4">
          <div>
            <h3 className="font-bold text-slate-800 text-lg">Manage Enrollment</h3>
            <p className="text-slate-500 text-sm">{course.code} — {course.name}</p>
          </div>
          <button onClick={onClose} className="p-1.5 text-slate-400 hover:text-slate-700 rounded-lg hover:bg-slate-100">
            <X size={18} />
          </button>
        </div>

        {loading ? (
          <div className="flex justify-center py-10 text-slate-400">Loading…</div>
        ) : (
          <div className="flex-1 overflow-y-auto space-y-4">
            {/* Enrolled students */}
            <div>
              <p className="text-xs font-semibold text-slate-500 uppercase mb-2">
                Enrolled ({enrolled.length})
              </p>
              {enrolled.length === 0 ? (
                <p className="text-sm text-slate-400">No students enrolled yet.</p>
              ) : (
                <ul className="space-y-1.5">
                  {enrolled.map(s => (
                    <li key={s.id} className="flex items-center justify-between bg-emerald-50 px-3 py-2 rounded-xl">
                      <div>
                        <span className="text-sm font-medium text-slate-700">{s.fullName}</span>
                        <span className="ml-2 text-xs text-slate-400">{s.regNumber || s.email}</span>
                      </div>
                      <button
                        onClick={() => handleUnenroll(s.id)}
                        disabled={busy === s.id}
                        className="p-1 text-red-400 hover:text-red-600 rounded hover:bg-red-50 transition-colors"
                      >
                        <UserMinus size={14} />
                      </button>
                    </li>
                  ))}
                </ul>
              )}
            </div>

            {/* Add students */}
            <div>
              <p className="text-xs font-semibold text-slate-500 uppercase mb-2">Add Student</p>
              <input
                value={search}
                onChange={e => setSearch(e.target.value)}
                placeholder="Search by name or reg number…"
                className="input w-full mb-2"
              />
              {available.length === 0 ? (
                <p className="text-sm text-slate-400">
                  {search ? 'No matching students.' : 'All students are already enrolled.'}
                </p>
              ) : (
                <ul className="space-y-1.5 max-h-48 overflow-y-auto">
                  {available.slice(0, 30).map(s => (
                    <li key={s.id} className="flex items-center justify-between bg-slate-50 px-3 py-2 rounded-xl">
                      <div>
                        <span className="text-sm font-medium text-slate-700">{s.fullName}</span>
                        <span className="ml-2 text-xs text-slate-400">{s.regNumber || s.email}</span>
                      </div>
                      <button
                        onClick={() => handleEnroll(s)}
                        disabled={busy === s.id}
                        className="p-1 text-blue-500 hover:text-blue-700 rounded hover:bg-blue-50 transition-colors"
                      >
                        <UserPlus size={14} />
                      </button>
                    </li>
                  ))}
                </ul>
              )}
            </div>
          </div>
        )}
      </div>
    </div>
  )
}

export default function Courses() {
  const [courses,   setCourses]   = useState([])
  const [lecturers, setLecturers] = useState([])
  const [students,  setStudents]  = useState([])
  const [loading,   setLoading]   = useState(true)
  const [saving,    setSaving]    = useState(false)

  const [showCreate,  setShowCreate]  = useState(false)
  const [editing,     setEditing]     = useState(null)
  const [enrolling,   setEnrolling]   = useState(null)

  useEffect(() => {
    Promise.all([
      api.get('/admin/courses'),
      api.get('/admin/users'),
    ]).then(([cr, ur]) => {
      setCourses(cr.data.data)
      const users = ur.data.data
      setLecturers(users.filter(u => u.role === 'lecturer'))
      setStudents(users.filter(u => u.role === 'student'))
      setLoading(false)
    })
  }, [])

  async function handleCreate(form) {
    setSaving(true)
    try {
      const r = await api.post('/admin/courses', form)
      setCourses(prev => [...prev, r.data.data])
      setShowCreate(false)
    } finally { setSaving(false) }
  }

  async function handleEdit(form) {
    setSaving(true)
    try {
      const r = await api.put(`/admin/courses/${editing.id}`, form)
      const updated = r.data.data
      const lec = form.lecturerId
        ? lecturers.find(l => l.id === form.lecturerId) || null
        : null
      setCourses(prev => prev.map(c =>
        c.id === editing.id
          ? { ...c, ...form, lecturer: lec ? { id: lec.id, fullName: lec.fullName } : null }
          : c
      ))
      setEditing(null)
    } finally { setSaving(false) }
  }

  async function handleDelete(id) {
    if (!confirm('Archive this course? Existing sessions and records are preserved.')) return
    await api.delete(`/admin/courses/${id}`)
    setCourses(prev => prev.filter(c => c.id !== id))
  }

  if (loading) return <div className="flex justify-center py-20 text-slate-400">Loading…</div>

  return (
    <div className="space-y-5">
      <div className="flex items-center justify-between">
        <div>
          <h2 className="text-xl font-bold text-slate-800">Course Management</h2>
          <p className="text-slate-500 text-sm mt-1">{courses.length} courses</p>
        </div>
        <button onClick={() => setShowCreate(true)} className="btn-primary flex items-center gap-2">
          <Plus size={16} /> Add Course
        </button>
      </div>

      <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 gap-4">
        {courses.map(c => (
          <div key={c.id} className="bg-white rounded-2xl p-5 shadow-sm border border-slate-100 hover:shadow-md transition-shadow">
            <div className="flex items-start justify-between mb-3">
              <div className="w-10 h-10 rounded-xl bg-blue-50 flex items-center justify-center">
                <BookOpen size={18} className="text-blue-600" />
              </div>
              <div className="flex items-center gap-1">
                <button
                  onClick={() => setEditing(c)}
                  className="p-1.5 text-slate-400 hover:text-blue-500 rounded-lg hover:bg-blue-50 transition-colors"
                  title="Edit course"
                >
                  <Pencil size={14} />
                </button>
                <button
                  onClick={() => handleDelete(c.id)}
                  className="p-1.5 text-slate-400 hover:text-red-500 rounded-lg hover:bg-red-50 transition-colors"
                  title="Archive course"
                >
                  <Trash2 size={14} />
                </button>
              </div>
            </div>
            <h3 className="font-bold text-slate-800">{c.name}</h3>
            <p className="text-sm text-slate-400 font-mono mt-0.5">{c.code}</p>
            <p className="text-xs text-slate-400 mt-1">{c.department}</p>
            <div className="mt-4 pt-4 border-t border-slate-100 flex items-center justify-between">
              <button
                onClick={() => setEnrolling(c)}
                className="flex items-center gap-1 text-slate-500 text-sm hover:text-blue-600 transition-colors"
              >
                <Users size={14} />
                <span>{c.students} students</span>
              </button>
              <span className="text-xs text-slate-400">
                {c.lecturer
                  ? c.lecturer.fullName
                  : <span className="text-amber-500">No lecturer</span>}
              </span>
            </div>
          </div>
        ))}
      </div>

      {showCreate && (
        <CourseModal
          lecturers={lecturers}
          onClose={() => setShowCreate(false)}
          onSubmit={handleCreate}
          loading={saving}
        />
      )}

      {editing && (
        <CourseModal
          initial={editing}
          lecturers={lecturers}
          onClose={() => setEditing(null)}
          onSubmit={handleEdit}
          loading={saving}
        />
      )}

      {enrolling && (
        <EnrollModal
          course={enrolling}
          students={students}
          onClose={() => setEnrolling(null)}
        />
      )}
    </div>
  )
}
