import { BrowserRouter, Routes, Route, Navigate } from 'react-router-dom'
import { AuthProvider, useAuth } from './context/AuthContext'
import Login from './pages/Login'
import ForgotPassword from './pages/ForgotPassword'
import Layout from './components/Layout'
import Dashboard from './pages/Dashboard'
import Sessions from './pages/Sessions'
import LiveMonitor from './pages/LiveMonitor'
import Students from './pages/Students'
import Reports from './pages/Reports'
import Appeals from './pages/Appeals'

function Protected({ children }) {
  const { user, loading } = useAuth()
  if (loading) return <div className="flex h-screen items-center justify-center text-gray-500">Loading…</div>
  return user ? children : <Navigate to="/login" replace />
}

export default function App() {
  return (
    <AuthProvider>
      <BrowserRouter>
        <Routes>
          <Route path="/login" element={<Login />} />
          <Route path="/forgot-password" element={<ForgotPassword />} />
          <Route path="/" element={<Protected><Layout /></Protected>}>
            <Route index element={<Dashboard />} />
            <Route path="sessions" element={<Sessions />} />
            <Route path="sessions/:id/live" element={<LiveMonitor />} />
            <Route path="students" element={<Students />} />
            <Route path="reports"  element={<Reports />} />
            <Route path="appeals"  element={<Appeals />} />
          </Route>
        </Routes>
      </BrowserRouter>
    </AuthProvider>
  )
}
