import { describe, it, expect, vi } from 'vitest'
import { render, screen } from '@testing-library/react'
import userEvent from '@testing-library/user-event'
import Sidebar from './Sidebar'

const menuItems = [
  { label: 'My Classes', path: '/teacher/classes' },
  {
    label: 'Content Studio',
    path: '/teacher/content-studio',
    nested: true,
    children: [{ label: 'Skill Library', path: '/teacher/content-studio/skills' }]
  }
]

describe('Sidebar', () => {
  it('renders the brand name', () => {
    render(<Sidebar role="teacher" menuItems={menuItems} activePath="/teacher/classes" onNavigate={vi.fn()} />)
    expect(screen.getByText('Study Platform')).toBeInTheDocument()
  })

  it('renders role badge in uppercase', () => {
    render(<Sidebar role="teacher" menuItems={menuItems} activePath="/teacher/classes" onNavigate={vi.fn()} />)
    expect(screen.getByText('TEACHER')).toBeInTheDocument()
  })

  it('renders all top-level nav items', () => {
    render(<Sidebar role="teacher" menuItems={menuItems} activePath="/teacher/classes" onNavigate={vi.fn()} />)
    expect(screen.getByText('My Classes')).toBeInTheDocument()
    expect(screen.getByText('Content Studio')).toBeInTheDocument()
  })

  it('marks the active item with active class', () => {
    render(<Sidebar role="teacher" menuItems={menuItems} activePath="/teacher/classes" onNavigate={vi.fn()} />)
    const btn = screen.getByText('My Classes').closest('button')
    expect(btn).toHaveClass('active')
  })

  it('does not mark inactive items as active', () => {
    render(<Sidebar role="teacher" menuItems={menuItems} activePath="/teacher/classes" onNavigate={vi.fn()} />)
    const btn = screen.getByText('Content Studio').closest('button')
    expect(btn).not.toHaveClass('active')
  })

  it('shows child nav items when parent is active', () => {
    render(
      <Sidebar
        role="teacher"
        menuItems={menuItems}
        activePath="/teacher/content-studio/skills"
        onNavigate={vi.fn()}
      />
    )
    expect(screen.getByText('Skill Library')).toBeInTheDocument()
  })

  it('hides child nav items when parent is not active', () => {
    render(<Sidebar role="teacher" menuItems={menuItems} activePath="/teacher/classes" onNavigate={vi.fn()} />)
    expect(screen.queryByText('Skill Library')).not.toBeInTheDocument()
  })

  it('calls onNavigate with the item path on click', async () => {
    const onNavigate = vi.fn()
    render(<Sidebar role="teacher" menuItems={menuItems} activePath="/teacher/classes" onNavigate={onNavigate} />)
    await userEvent.click(screen.getByText('Content Studio'))
    expect(onNavigate).toHaveBeenCalledWith('/teacher/content-studio')
  })
})
