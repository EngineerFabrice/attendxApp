import { useEffect, useState } from 'react'
import { Save, Bell, Clock, Database, Shield, Loader2 } from 'lucide-react'
import api from '../services/api'

function Toggle({ value, onChange }) {
  return (
    <button
      onClick={() => onChange(!value)}
      className={`relative w-11 h-6 rounded-full transition-colors ${value ? 'bg-blue-600' : 'bg-slate-200'}`}
    >
      <span className={`absolute top-0.5 left-0.5 w-5 h-5 bg-white rounded-full shadow transition-transform ${value ? 'translate-x-5' : ''}`} />
    </button>
  )
}

export default function Settings() {
  const [notifs, setNotifs] = useState({ sessionStart: true, absenceAlert: true, lowAttendance: true, weeklyReport: false })
  const [sessionTtl, setSessionTtl] = useState(90)
  const [geofenceRadius, setGeofenceRadius] = useState(30)
  const [lateThreshold, setLateThreshold] = useState(15)
  const [loading, setLoading] = useState(true)
  const [saving, setSaving] = useState(false)
  const [saved, setSaved] = useState(false)
  const [error, setError] = useState(null)

  useEffect(() => {
    api.get('/admin/settings')
      .then(r => {
        const d = r.data.data
        if (d.notificationPrefs) setNotifs(d.notificationPrefs)
        if (d.sessionTtlMinutes)   setSessionTtl(d.sessionTtlMinutes)
        if (d.geofenceRadiusM)     setGeofenceRadius(d.geofenceRadiusM)
        if (d.lateThresholdMinutes) setLateThreshold(d.lateThresholdMinutes)
      })
      .catch(() => { /* keep defaults if endpoint missing */ })
      .finally(() => setLoading(false))
  }, [])

  async function handleSave() {
    setSaving(true)
    setError(null)
    try {
      await api.put('/admin/settings', {
        notificationPrefs: notifs,
        sessionTtlMinutes: Number(sessionTtl),
        geofenceRadiusM: Number(geofenceRadius),
        lateThresholdMinutes: Number(lateThreshold),
      })
      setSaved(true)
      setTimeout(() => setSaved(false), 2500)
    } catch (err) {
      setError(err.response?.data?.error || 'Failed to save settings')
    } finally {
      setSaving(false)
    }
  }

  async function handleExport(format) {
    try {
      const r = await api.get(`/admin/export?format=${format}`, { responseType: 'blob' })
      const url = URL.createObjectURL(r.data)
      const a = document.createElement('a')
      a.href = url
      a.download = `attendx_export.${format}`
      a.click()
      URL.revokeObjectURL(url)
    } catch {
      alert('Export failed')
    }
  }

  if (loading) return <div className="flex justify-center py-20 text-slate-400">Loading…</div>

  return (
    <div className="space-y-6 max-w-2xl">
      <div>
        <h2 className="text-xl font-bold text-slate-800">System Settings</h2>
        <p className="text-slate-500 text-sm mt-1">Configure global system behaviour</p>
      </div>

      {error && (
        <div className="flex items-center justify-between bg-red-50 border border-red-200 text-red-700 px-4 py-3 rounded-xl text-sm">
          {error}
          <button onClick={() => setError(null)} className="ml-4 font-bold text-lg leading-none">&times;</button>
        </div>
      )}

      {/* Notifications */}
      <div className="bg-white rounded-2xl p-5 shadow-sm border border-slate-100">
        <div className="flex items-center gap-2 mb-4">
          <Bell size={18} className="text-blue-600" />
          <h3 className="font-semibold text-slate-800">Notification Settings</h3>
        </div>
        <div className="space-y-4">
          {[
            { key: 'sessionStart',   label: 'Session start alerts',       desc: 'Notify students when a session starts' },
            { key: 'absenceAlert',   label: 'Absence alerts',             desc: 'Alert lecturers when attendance drops' },
            { key: 'lowAttendance',  label: 'Low attendance warnings',    desc: `Warn students below threshold` },
            { key: 'weeklyReport',   label: 'Weekly digest',              desc: 'Send weekly summary emails to admins' },
          ].map(({ key, label, desc }) => (
            <div key={key} className="flex items-center justify-between py-2">
              <div>
                <p className="text-slate-700 font-medium text-sm">{label}</p>
                <p className="text-slate-400 text-xs mt-0.5">{desc}</p>
              </div>
              <Toggle value={notifs[key]} onChange={v => setNotifs(n => ({ ...n, [key]: v }))} />
            </div>
          ))}
        </div>
      </div>

      {/* Session config */}
      <div className="bg-white rounded-2xl p-5 shadow-sm border border-slate-100">
        <div className="flex items-center gap-2 mb-4">
          <Clock size={18} className="text-blue-600" />
          <h3 className="font-semibold text-slate-800">Session Configuration</h3>
        </div>
        <div className="grid grid-cols-3 gap-4">
          <div>
            <label className="text-slate-600 text-sm">Session TTL (minutes)</label>
            <input type="number" value={sessionTtl} onChange={e => setSessionTtl(e.target.value)} min={10} max={300} className="input mt-1.5" />
          </div>
          <div>
            <label className="text-slate-600 text-sm">Default Geofence Radius (m)</label>
            <input type="number" value={geofenceRadius} onChange={e => setGeofenceRadius(e.target.value)} min={10} max={200} className="input mt-1.5" />
          </div>
          <div>
            <label className="text-slate-600 text-sm">Late Threshold (minutes)</label>
            <input type="number" value={lateThreshold} onChange={e => setLateThreshold(e.target.value)} min={1} max={60} className="input mt-1.5" />
          </div>
        </div>
      </div>

      {/* Security */}
      <div className="bg-white rounded-2xl p-5 shadow-sm border border-slate-100">
        <div className="flex items-center gap-2 mb-4">
          <Shield size={18} className="text-blue-600" />
          <h3 className="font-semibold text-slate-800">Security</h3>
        </div>
        <div className="space-y-3">
          <div className="flex items-center justify-between py-2">
            <div>
              <p className="text-slate-700 font-medium text-sm">Device fingerprinting</p>
              <p className="text-slate-400 text-xs">Track student check-in devices</p>
            </div>
            <Toggle value={true} onChange={() => {}} />
          </div>
          <div className="flex items-center justify-between py-2">
            <div>
              <p className="text-slate-700 font-medium text-sm">VPN / Proxy blocking</p>
              <p className="text-slate-400 text-xs">Block check-ins from VPN or proxy IPs</p>
            </div>
            <Toggle value={true} onChange={() => {}} />
          </div>
        </div>
      </div>

      {/* Backup */}
      <div className="bg-white rounded-2xl p-5 shadow-sm border border-slate-100">
        <div className="flex items-center gap-2 mb-4">
          <Database size={18} className="text-blue-600" />
          <h3 className="font-semibold text-slate-800">Data Export</h3>
        </div>
        <div className="flex gap-3">
          <button onClick={() => handleExport('csv')}  className="btn-secondary">Export CSV</button>
          <button onClick={() => handleExport('json')} className="btn-secondary">Export JSON</button>
        </div>
      </div>

      <button onClick={handleSave} disabled={saving} className="btn-primary flex items-center gap-2">
        {saving ? <Loader2 size={16} className="animate-spin" /> : <Save size={16} />}
        {saving ? 'Saving…' : saved ? '✓ Saved!' : 'Save Settings'}
      </button>
    </div>
  )
}
