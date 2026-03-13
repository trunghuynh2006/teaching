import { useEffect, useMemo, useState } from 'react'
import { Navigate, Route, Routes, useLocation, useNavigate } from 'react-router-dom'
import Sidebar from './components/Sidebar'
import TeacherContentStudio from './components/TeacherContentStudio'
import {
  MENU_BY_ROLE,
  MenuItem,
  Role,
  SIDEBAR_BY_SECTION,
  TEACHER_SECTIONS,
} from './config/menu'
import LoginPage from './pages/LoginPage'
import { AdminLanding, LearnerLanding, ParentLanding } from './pages/LandingPages'

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
  admin: (props) => <AdminLanding {...props} />,
  parent: (props) => <ParentLanding {...props} />,
}

function TeacherClasses() {
  return (
    <section className="panel">
      <h2>My Classes</h2>
      <p>Coming soon.</p>
    </section>
  )
}

function TeacherGradebook() {
  return (
    <section className="panel">
      <h2>Gradebook</h2>
      <p>Coming soon.</p>
    </section>
  )
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

  // Context-based sidebar: teacher uses section map, others use role map
  const sidebarItems: MenuItem[] = useMemo(() => {
    if (role === 'teacher') {
      const section = TEACHER_SECTIONS.find((s) => location.pathname.startsWith(s.path))
      return section ? (SIDEBAR_BY_SECTION[section.path] ?? []) : []
    }
    if (role === 'learner') return []
    return MENU_BY_ROLE[role as Role] ?? []
  }, [role, location.pathname])

  const menuItems = MENU_BY_ROLE[role as Role] ?? []
  const defaultPath =
    role === 'teacher'
      ? '/teacher/content-studio/skills'
      : role === 'learner'
      ? '/learner/folders'
      : menuItems[0]?.path ?? '/'

  // Redirect unknown paths for non-teacher roles
  useEffect(() => {
    if (role === 'teacher' || !token || !user || menuItems.length === 0) return
    const isKnownPath = menuItems.some(
      (item) => location.pathname === item.path || location.pathname.startsWith(`${item.path}/`)
    )
    if (!isKnownPath) navigate(defaultPath, { replace: true })
  }, [defaultPath, location.pathname, menuItems, navigate, token, user, role])

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

  const activeSection = TEACHER_SECTIONS.find((s) => location.pathname.startsWith(s.path))
  const Landing = LANDING_BY_ROLE[role]

  return (
    <main className="app-shell">
      <Sidebar
        menuItems={sidebarItems}
        activePath={location.pathname + location.search}
        userName={user.full_name ?? user.FullName ?? role}
        onNavigate={navigate}
        onLogout={handleLogout}
        folderSection={role === 'learner' ? { token, activePath: location.pathname + location.search, onNavigate: navigate } : undefined}
      />
      <section className="content-area">
        <header className="topbar">
          {role === 'teacher' ? (
            <nav className="section-tabs">
              {TEACHER_SECTIONS.map((s) => (
                <button
                  key={s.path}
                  className={`section-tab${activeSection?.path === s.path ? ' active' : ''}`}
                  onClick={() => navigate(s.defaultPath)}
                >
                  {s.label}
                </button>
              ))}
            </nav>
          ) : (
            <span className="topbar-brand">Study Platform</span>
          )}
        </header>
        <Routes>
          {role === 'teacher' ? (
            <>
              <Route path="/teacher/classes" element={<TeacherClasses />} />
              <Route path="/teacher/gradebook" element={<TeacherGradebook />} />
              <Route
                path="/teacher/content-studio/*"
                element={<TeacherContentStudio token={token} onUnauthorized={handleLogout} />}
              />
              <Route path="*" element={<Navigate to="/teacher/content-studio/skills" replace />} />
            </>
          ) : role === 'learner' ? (
            <>
              <Route path="/learner/folders" element={<LearnerLanding activeItem="Folders" token={token} onUnauthorized={handleLogout} />} />
              <Route path="/learner/recorder" element={<LearnerLanding activeItem="Voice Recorder" token={token} onUnauthorized={handleLogout} />} />
              <Route path="/learner/audio-records" element={<LearnerLanding activeItem="Audio Records" token={token} onUnauthorized={handleLogout} />} />
              <Route path="/learner/anki-review" element={<LearnerLanding activeItem="Anki Review" token={token} onUnauthorized={handleLogout} />} />
              <Route path="*" element={<Navigate to="/learner/folders" replace />} />
            </>
          ) : (
            <>
              {menuItems.map((item) => (
                <Route
                  key={item.path}
                  path={item.path}
                  element={
                    Landing ? (
                      <Landing activeItem={item.label} token={token} onUnauthorized={handleLogout} />
                    ) : null
                  }
                />
              ))}
              <Route path="*" element={<Navigate to={defaultPath} replace />} />
            </>
          )}
        </Routes>
      </section>
    </main>
  )
}
