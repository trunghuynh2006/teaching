import { useMemo, useState } from 'react'
import Sidebar from './components/Sidebar'
import {
  LearnerLanding,
  TeacherLanding,
  AdminLanding,
  ParentLanding
} from './pages/LandingPages'
import { API_URL } from './config'

const DEFAULT_MENU = {
  learner: 'My Courses',
  teacher: 'My Classes',
  admin: 'User Management',
  parent: 'Child Overview'
}

function renderLanding(role, activeItem) {
  switch (role) {
    case 'learner':
      return <LearnerLanding activeItem={activeItem} />
    case 'teacher':
      return <TeacherLanding activeItem={activeItem} />
    case 'admin':
      return <AdminLanding activeItem={activeItem} />
    case 'parent':
      return <ParentLanding activeItem={activeItem} />
    default:
      return null
  }
}

export default function App() {
  const [username, setUsername] = useState('')
  const [password, setPassword] = useState('')
  const [token, setToken] = useState('')
  const [user, setUser] = useState(null)
  const [error, setError] = useState('')
  const [activeItem, setActiveItem] = useState('')

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
      setToken(data.access_token)
      setUser(data.user)
      setActiveItem(DEFAULT_MENU[data.user.role])
      setUsername('')
      setPassword('')
    } catch (err) {
      setError(err.message)
    }
  }

  const handleLogout = () => {
    setToken('')
    setUser(null)
    setActiveItem('')
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
      <Sidebar role={user.role} activeItem={activeItem} onSelect={setActiveItem} />
      <section className="content-area">
        <header className="topbar">
          <div>
            <h1>Welcome, {user.full_name}</h1>
            <p>{user.role} dashboard</p>
          </div>
          <button onClick={handleLogout}>Logout</button>
        </header>
        {renderLanding(user.role, activeItem)}
      </section>
    </main>
  )
}
