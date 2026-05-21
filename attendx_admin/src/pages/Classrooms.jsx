import { useEffect, useState } from 'react'
import { Plus, MapPin, Trash2 } from 'lucide-react'
import api from '../services/api'

function Modal({ onClose, onSubmit, loading }) {
  const [form, setForm] = useState({ name: '', building: '', capacity: 60, latitude: '', longitude: '', radiusM: 30 })
  const set = k => e => setForm(f => ({ ...f, [k]: e.target.value }))

  return (
    <div className="fixed inset-0 bg-black/50 z-50 flex items-center justify-center p-4">
      <div className="bg-white rounded-2xl p-6 w-full max-w-md shadow-2xl">
        <h3 className="font-bold text-slate-800 text-lg mb-5">Add Classroom</h3>
        <form onSubmit={e => { e.preventDefault(); onSubmit({ ...form, latitude: parseFloat(form.latitude), longitude: parseFloat(form.longitude), capacity: parseInt(form.capacity), radiusM: parseInt(form.radiusM) }) }} className="space-y-3">
          <input required value={form.name} onChange={set('name')} placeholder="Room name (e.g. LT-6)" className="input" />
          <input required value={form.building} onChange={set('building')} placeholder="Building" className="input" />
          <input required type="number" value={form.capacity} onChange={set('capacity')} placeholder="Capacity" className="input" />
          <div className="grid grid-cols-2 gap-3">
            <input required type="number" step="any" value={form.latitude} onChange={set('latitude')} placeholder="Latitude" className="input" />
            <input required type="number" step="any" value={form.longitude} onChange={set('longitude')} placeholder="Longitude" className="input" />
          </div>
          <div className="flex items-center gap-3">
            <label className="text-slate-600 text-sm whitespace-nowrap">Geofence radius:</label>
            <input required type="number" value={form.radiusM} onChange={set('radiusM')} min={10} max={200} className="input" />
            <span className="text-slate-400 text-sm">m</span>
          </div>
          <div className="flex gap-3 pt-2">
            <button type="button" onClick={onClose} className="flex-1 btn-secondary">Cancel</button>
            <button type="submit" disabled={loading} className="flex-1 btn-primary">{loading ? 'Saving…' : 'Add Classroom'}</button>
          </div>
        </form>
      </div>
    </div>
  )
}

export default function Classrooms() {
  const [rooms, setRooms] = useState([])
  const [loading, setLoading] = useState(true)
  const [saving, setSaving] = useState(false)
  const [showModal, setShowModal] = useState(false)

  useEffect(() => {
    api.get('/admin/classrooms').then(r => { setRooms(r.data.data); setLoading(false) })
  }, [])

  async function handleCreate(form) {
    setSaving(true)
    try {
      const res = await api.post('/admin/classrooms', form)
      setRooms(prev => [...prev, res.data.data])
      setShowModal(false)
    } finally {
      setSaving(false)
    }
  }

  async function handleDelete(id) {
    if (!confirm('Delete this classroom?')) return
    await api.delete(`/admin/classrooms/${id}`)
    setRooms(prev => prev.filter(x => x.id !== id))
  }

  if (loading) return <div className="flex justify-center py-20 text-slate-400">Loading…</div>

  return (
    <div className="space-y-5">
      <div className="flex items-center justify-between">
        <div>
          <h2 className="text-xl font-bold text-slate-800">Classroom Management</h2>
          <p className="text-slate-500 text-sm mt-1">{rooms.length} rooms with GPS geofencing</p>
        </div>
        <button onClick={() => setShowModal(true)} className="btn-primary flex items-center gap-2">
          <Plus size={16} /> Add Classroom
        </button>
      </div>

      <div className="bg-white rounded-2xl shadow-sm border border-slate-100 overflow-hidden">
        <table className="w-full">
          <thead>
            <tr className="border-b border-slate-100">
              <th className="th">Room</th>
              <th className="th">Building</th>
              <th className="th">Capacity</th>
              <th className="th">GPS Coordinates</th>
              <th className="th">Geofence</th>
              <th className="th">Actions</th>
            </tr>
          </thead>
          <tbody>
            {rooms.map(r => (
              <tr key={r.id} className="border-b border-slate-50 hover:bg-slate-50 transition-colors">
                <td className="td font-semibold text-slate-800 flex items-center gap-2">
                  <MapPin size={14} className="text-blue-500" />{r.name}
                </td>
                <td className="td text-slate-500">{r.building}</td>
                <td className="td text-slate-600">{r.capacity}</td>
                <td className="td font-mono text-xs text-slate-500">
                  {r.latitude.toFixed(4)}, {r.longitude.toFixed(4)}
                </td>
                <td className="td">
                  <span className="badge badge-blue">{r.radiusM}m</span>
                </td>
                <td className="td">
                  <button onClick={() => handleDelete(r.id)} className="p-1.5 text-slate-400 hover:text-red-500 rounded-lg hover:bg-red-50 transition-colors">
                    <Trash2 size={15} />
                  </button>
                </td>
              </tr>
            ))}
          </tbody>
        </table>
      </div>

      {showModal && <Modal onClose={() => setShowModal(false)} onSubmit={handleCreate} loading={saving} />}
    </div>
  )
}
