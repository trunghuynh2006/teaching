import { useMemo, useState } from 'react'
import { API_URL } from '../config'
import { MENU_BY_ROLE } from '../config/menu'

const DEMO_USERS = [
  'learner_alex / Pass1234!',
  'learner_mia / Pass1234!',
  'teacher_john / Teach1234!',
  'teacher_nina / Teach1234!',
  'admin_sara / Admin1234!',
  'admin_mike / Admin1234!',
  'parent_olivia / Parent1234!',
  'parent_david / Parent1234!'
]

export default function LoginPage({ onLogin }) {
  const [username, setUsername] = useState('')
  const [password, setPassword] = useState('')
  const [error, setError] = useState('')

  const demoUsers = useMemo(() => DEMO_USERS, [])

  const handleSubmit = async (e) => {
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

      const defaultPath = MENU_BY_ROLE[role]?.[0]?.path || '/'
      onLogin({ token: accessToken, user: userPayload, defaultPath })
    } catch (err) {
      setError(err.message)
    }
  }

  return (
    <main className="login-screen">
      <section className="login-card">
        <h1>Study Platform</h1>
        <p>Role-based learning portal</p>
        <form onSubmit={handleSubmit} className="login-form">
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
