import { useEffect, useRef, useState } from 'react'
import { MenuItem } from '../config/menu'

interface SidebarProps {
  menuItems: MenuItem[]
  activePath: string
  userName: string
  onNavigate: (path: string) => void
  onLogout: () => void
}

function getInitials(name: string): string {
  return name
    .split(' ')
    .filter(Boolean)
    .slice(0, 2)
    .map((w) => w[0].toUpperCase())
    .join('')
}

export default function Sidebar({ menuItems, activePath, userName, onNavigate, onLogout }: SidebarProps) {
  const [menuOpen, setMenuOpen] = useState(false)
  const menuRef = useRef<HTMLDivElement>(null)

  useEffect(() => {
    if (!menuOpen) return
    function handleClick(e: MouseEvent) {
      if (menuRef.current && !menuRef.current.contains(e.target as Node)) {
        setMenuOpen(false)
      }
    }
    document.addEventListener('mousedown', handleClick)
    return () => document.removeEventListener('mousedown', handleClick)
  }, [menuOpen])

  return (
    <aside className="sidebar">
      <div className="brand-icon">SP</div>

      <nav>
        {menuItems.map((item) => {
          const isActive = activePath === item.path || activePath.startsWith(`${item.path}/`)
          return (
            <button
              key={item.path}
              className={`nav-item${isActive ? ' active' : ''}`}
              title={item.label}
              onClick={() => onNavigate(item.path)}
            >
              <span className="nav-icon">{item.icon}</span>
            </button>
          )
        })}
      </nav>

      <div className="sidebar-user" ref={menuRef}>
        <button
          className="user-avatar"
          title={userName}
          onClick={() => setMenuOpen((prev) => !prev)}
        >
          {getInitials(userName)}
        </button>

        {menuOpen && (
          <div className="user-popup">
            <div className="user-popup-name">{userName}</div>
            <hr className="user-popup-divider" />
            <button
              className="user-popup-item"
              onClick={() => { setMenuOpen(false); onLogout() }}
            >
              Sign out
            </button>
          </div>
        )}
      </div>
    </aside>
  )
}
