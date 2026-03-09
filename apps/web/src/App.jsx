import { useEffect, useMemo, useState } from 'react'
import { Navigate, Route, Routes, useLocation, useNavigate } from 'react-router-dom'
import Sidebar from './components/Sidebar'
import {
  LearnerLanding,
  TeacherLanding,
  AdminLanding,
  ParentLanding
} from './pages/LandingPages'
import { API_URL } from './config'

const MENU_BY_ROLE = {
  learner: [
    { label: 'My Courses', path: '/learner/courses' },
    { label: 'Assignments', path: '/learner/assignments' },
    { label: 'Progress', path: '/learner/progress' }
  ],
  teacher: [
    { label: 'My Classes', path: '/teacher/classes' },
    { label: 'Gradebook', path: '/teacher/gradebook' },
    {
      label: 'Content Studio',
      path: '/teacher/content-studio',
      nested: true,
      children: [
        { label: 'Skill Library', path: '/teacher/content-studio/skills' }
      ]
    }
  ],
  admin: [
    { label: 'User Management', path: '/admin/user-management' },
    { label: 'System Health', path: '/admin/system-health' },
    { label: 'Reports', path: '/admin/reports' }
  ],
  parent: [
    { label: 'Child Overview', path: '/parent/child-overview' },
    { label: 'Attendance', path: '/parent/attendance' },
    { label: 'Teacher Notes', path: '/parent/teacher-notes' }
  ]
}

function renderLanding(role, activeItem, token) {
  switch (role) {
    case 'learner':
      return <LearnerLanding activeItem={activeItem} />
    case 'teacher':
      return <TeacherLanding activeItem={activeItem} token={token} />
    case 'admin':
      return <AdminLanding activeItem={activeItem} />
    case 'parent':
      return <ParentLanding activeItem={activeItem} />
    default:
      return null
  }
}

export default function App() {
  const location = useLocation()
  const navigate = useNavigate()
  const [username, setUsername] = useState('')
  const [password, setPassword] = useState('')
  const [token, setToken] = useState('')
  const [user, setUser] = useState(null)
  const [error, setError] = useState('')

  const demoUsers = useMemo(
    () => [
      'learner_alex / Pass1234!',
      'learner_mia / Pass1234!',
      'teacher_john / Teach1234!',
      'teacher_nina / Teach1234!',
      'admin_sara / Admin1234!',
      'admin_mike / Admin1234!',
      'parent_olivia / Parent1234!',
      'parent_david / Parent1234!'
    ],
    []
  )

  const role = user?.role ?? user?.Role ?? ''
  const menuItems = useMemo(() => MENU_BY_ROLE[role] || [], [role])
  const defaultPath = menuItems[0]?.path || '/'
  const activeItem =
    menuItems.find(
      (item) =>
        location.pathname === item.path || location.pathname.startsWith(`${item.path}/`)
    )?.label || ''

  useEffect(() => {
    if (!token || !user || menuItems.length === 0) {
      return
    }

    const isKnownPath = menuItems.some(
      (item) =>
        location.pathname === item.path || location.pathname.startsWith(`${item.path}/`)
    )
    if (!isKnownPath) {
      navigate(defaultPath, { replace: true })
    }
  }, [defaultPath, location.pathname, menuItems, navigate, token, user])

  const handleLogin = async (e) => {
    e.preventDefault()
    setError('')

    try {
      const response = await fetch(`${API_URL}/auth/login`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ username, password })
      })

      if (!response.ok) {
        const data = await response.json()
        throw new Error(data.detail || 'Login failed')
      }

      const data = await response.json()
      const accessToken = data.access_token ?? data.AccessToken ?? ''
      const userPayload = data.user ?? data.User ?? null
      const role = userPayload?.role ?? userPayload?.Role ?? ''

      if (!accessToken || !userPayload || !role) {
        throw new Error('Login response is missing required fields')
      }

      setToken(accessToken)
      setUser(userPayload)
      const roleRoutes = MENU_BY_ROLE[role] || []
      navigate(roleRoutes[0]?.path || '/', { replace: true })
      setUsername('')
      setPassword('')
    } catch (err) {
      setError(err.message)
    }
  }

  const handleLogout = () => {
    setToken('')
    setUser(null)
    navigate('/', { replace: true })
  }

  if (!token || !user) {
    return (
      <main className="login-screen">
        <section className="login-card">
          <h1>Study Platform</h1>
          <p>Role-based learning portal</p>
          <form onSubmit={handleLogin} className="login-form">
            <input
              placeholder="Username"
              value={username}
              onChange={(e) => setUsername(e.target.value)}
              required
            />
            <input
              type="password"
              placeholder="Password"
              value={password}
              onChange={(e) => setPassword(e.target.value)}
              required
            />
            <button type="submit">Login</button>
          </form>
          {error && <div className="error">{error}</div>}
          <div className="demo-users">
            <strong>Demo users:</strong>
            {demoUsers.map((u) => (
              <div key={u}>{u}</div>
            ))}
          </div>
        </section>
      </main>
    )
  }

  return (
    <main className="app-shell">
      <Sidebar
        role={role}
        menuItems={menuItems}
        activePath={location.pathname}
        onNavigate={navigate}
      />
      <section className="content-area">
        <header className="topbar">
          <div>
            <h1>Welcome, {user.full_name ?? user.FullName}</h1>
            <p>{role} dashboard</p>
          </div>
          <button onClick={handleLogout}>Logout</button>
        </header>
        <Routes>
          {menuItems.map((item) => (
            <Route
              key={item.path}
              path={item.nested ? `${item.path}/*` : item.path}
              element={renderLanding(role, item.label, token)}
            />
          ))}
          <Route path="*" element={<Navigate to={defaultPath} replace />} />
        </Routes>
      </section>
    </main>
  )
}
