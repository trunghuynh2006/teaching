import { describe, it, expect, vi, beforeEach, afterEach } from 'vitest'
import { render, screen, waitFor } from '@testing-library/react'
import userEvent from '@testing-library/user-event'
import LoginPage from './LoginPage'

async function fillAndSubmit(username: string, password: string) {
  const user = userEvent.setup()
  await user.type(screen.getByPlaceholderText('Username'), username)
  await user.type(screen.getByPlaceholderText('Password'), password)
  await user.click(screen.getByRole('button', { name: /login/i }))
}

describe('LoginPage', () => {
  beforeEach(() => {
    global.fetch = vi.fn()
  })

  afterEach(() => {
    vi.restoreAllMocks()
  })

  it('renders the heading', () => {
    render(<LoginPage onLogin={vi.fn()} />)
    expect(screen.getByRole('heading', { name: /study platform/i })).toBeInTheDocument()
  })

  it('renders username and password inputs', () => {
    render(<LoginPage onLogin={vi.fn()} />)
    expect(screen.getByPlaceholderText('Username')).toBeInTheDocument()
    expect(screen.getByPlaceholderText('Password')).toBeInTheDocument()
  })

  it('renders demo users list', () => {
    render(<LoginPage onLogin={vi.fn()} />)
    expect(screen.getByText(/learner_alex/)).toBeInTheDocument()
    expect(screen.getByText(/teacher_john/)).toBeInTheDocument()
  })

  it('calls onLogin with token and user on successful login', async () => {
    const onLogin = vi.fn()
    vi.mocked(global.fetch).mockResolvedValueOnce({
      ok: true,
      json: async () => ({
        access_token: 'tok123',
        user: { role: 'teacher', full_name: 'John' }
      })
    } as Response)

    render(<LoginPage onLogin={onLogin} />)
    await fillAndSubmit('teacher_john', 'Teach1234!')

    await waitFor(() => {
      expect(onLogin).toHaveBeenCalledWith(
        expect.objectContaining({ token: 'tok123' })
      )
    })
  })

  it('shows error message on failed login', async () => {
    vi.mocked(global.fetch).mockResolvedValueOnce({
      ok: false,
      json: async () => ({ detail: 'Invalid credentials' })
    } as Response)

    render(<LoginPage onLogin={vi.fn()} />)
    await fillAndSubmit('bad_user', 'wrong')

    await waitFor(() => {
      expect(screen.getByText('Invalid credentials')).toBeInTheDocument()
    })
  })

  it('shows generic error when response is missing required fields', async () => {
    vi.mocked(global.fetch).mockResolvedValueOnce({
      ok: true,
      json: async () => ({ access_token: '', user: null })
    } as Response)

    render(<LoginPage onLogin={vi.fn()} />)
    await fillAndSubmit('teacher_john', 'Teach1234!')

    await waitFor(() => {
      expect(screen.getByText(/missing required fields/i)).toBeInTheDocument()
    })
  })

  it('shows error when fetch throws a network error', async () => {
    vi.mocked(global.fetch).mockRejectedValueOnce(new Error('Network error'))

    render(<LoginPage onLogin={vi.fn()} />)
    await fillAndSubmit('teacher_john', 'Teach1234!')

    await waitFor(() => {
      expect(screen.getByText('Network error')).toBeInTheDocument()
    })
  })
})
