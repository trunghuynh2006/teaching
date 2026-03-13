import { describe, it, expect, vi } from 'vitest'
import { render, screen } from '@testing-library/react'
import userEvent from '@testing-library/user-event'
import Sidebar from './Sidebar'
import { MenuItem } from '../config/menu'

const menuItems: MenuItem[] = [
  { label: 'Skill Library', path: '/teacher/content-studio/skills', icon: '📚' },
  { label: 'Folders',       path: '/teacher/content-studio/folders', icon: '📁' },
]

const defaultProps = {
  menuItems,
  activePath: '/teacher/content-studio/skills',
  userName: 'John Carter',
  onNavigate: vi.fn(),
  onLogout: vi.fn(),
}

describe('Sidebar', () => {
  it('renders the brand abbreviation', () => {
    render(<Sidebar {...defaultProps} />)
    expect(screen.getByText('SP')).toBeInTheDocument()
  })

  it('renders a button for each menu item', () => {
    render(<Sidebar {...defaultProps} />)
    expect(screen.getByTitle('Skill Library')).toBeInTheDocument()
    expect(screen.getByTitle('Folders')).toBeInTheDocument()
  })

  it('marks the active item with active class', () => {
    render(<Sidebar {...defaultProps} />)
    expect(screen.getByTitle('Skill Library')).toHaveClass('active')
  })

  it('does not mark inactive items as active', () => {
    render(<Sidebar {...defaultProps} />)
    expect(screen.getByTitle('Folders')).not.toHaveClass('active')
  })

  it('calls onNavigate with the item path on click', async () => {
    const onNavigate = vi.fn()
    render(<Sidebar {...defaultProps} onNavigate={onNavigate} />)
    await userEvent.click(screen.getByTitle('Folders'))
    expect(onNavigate).toHaveBeenCalledWith('/teacher/content-studio/folders')
  })

  it('renders user initials in the avatar button', () => {
    render(<Sidebar {...defaultProps} />)
    expect(screen.getByTitle('John Carter')).toHaveTextContent('JC')
  })

  it('shows popup with sign-out on avatar click', async () => {
    render(<Sidebar {...defaultProps} />)
    await userEvent.click(screen.getByTitle('John Carter'))
    expect(screen.getByText('Sign out')).toBeInTheDocument()
    expect(screen.getByText('John Carter')).toBeInTheDocument()
  })

  it('calls onLogout when sign-out is clicked', async () => {
    const onLogout = vi.fn()
    render(<Sidebar {...defaultProps} onLogout={onLogout} />)
    await userEvent.click(screen.getByTitle('John Carter'))
    await userEvent.click(screen.getByText('Sign out'))
    expect(onLogout).toHaveBeenCalled()
  })
})
