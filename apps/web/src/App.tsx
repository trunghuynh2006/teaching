import { useEffect, useMemo, useState } from 'react'
import { Navigate, Route, Routes, useLocation, useNavigate } from 'react-router-dom'
import Sidebar from './components/Sidebar'
import { MENU_BY_ROLE, MenuItem, Role } from './config/menu'
import LoginPage from './pages/LoginPage'
import { AdminLanding, LearnerLanding, ParentLanding, TeacherLanding } from './pages/LandingPages'

interface User {
  role?: string
  Role?: string
  full_name?: string
  FullName?: string
}

interface LandingProps {
  activeItem?: string
  token?: string
  onUnauthorized?: () => void
}

type LandingComponent = (props: LandingProps) => React.ReactElement

const LANDING_BY_ROLE: Record<string, LandingComponent> = {
  learner: (props) => <LearnerLanding {...props} />,
  teacher: (props) => <TeacherLanding {...props} />,
  admin: (props) => <AdminLanding {...props} />,
  parent: (props) => <ParentLanding {...props} />
}

export default function App() {
  const location = useLocation()
  const navigate = useNavigate()
  const [token, setToken] = useState(() => localStorage.getItem('token') || '')
  const [user, setUser] = useState<User | null>(() => {
    try {
      const raw = localStorage.getItem('user')
      return raw ? JSON.parse(raw) : null
    } catch {
      return null
    }
  })

  const role = user?.role ?? user?.Role ?? ''
  const menuItems: MenuItem[] = useMemo(() => MENU_BY_ROLE[role as Role] || [], [role])
  const defaultPath = menuItems[0]?.path || '/'

  useEffect(() => {
    if (!token || !user || menuItems.length === 0) return
    const isKnownPath = menuItems.some(
      (item) => location.pathname === item.path || location.pathname.startsWith(`${item.path}/`)
    )
    if (!isKnownPath) navigate(defaultPath, { replace: true })
  }, [defaultPath, location.pathname, menuItems, navigate, token, user])

  const handleLogin = ({ token, user, defaultPath }: { token: string; user: User; defaultPath: string }) => {
    localStorage.setItem('token', token)
    localStorage.setItem('user', JSON.stringify(user))
    setToken(token)
    setUser(user)
    navigate(defaultPath, { replace: true })
  }

  const handleLogout = () => {
    localStorage.removeItem('token')
    localStorage.removeItem('user')
    setToken('')
    setUser(null)
    navigate('/', { replace: true })
  }

  if (!token || !user) {
    return <LoginPage onLogin={handleLogin} />
  }

  const Landing = LANDING_BY_ROLE[role]

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
              element={<Landing activeItem={item.label} token={token} onUnauthorized={handleLogout} />}
            />
          ))}
          <Route path="*" element={<Navigate to={defaultPath} replace />} />
        </Routes>
      </section>
    </main>
  )
}
