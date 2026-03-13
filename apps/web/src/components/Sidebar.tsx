import { useCallback, useEffect, useRef, useState } from 'react'
import { API_URL } from '../config'
import { MenuItem } from '../config/menu'

interface FolderSectionProps {
  token: string
  activePath: string
  onNavigate: (path: string) => void
}

interface SidebarFolder {
  id: string
  name: string
}

function FolderSection({ token, activePath, onNavigate }: FolderSectionProps) {
  const [folders, setFolders] = useState<SidebarFolder[]>([])
  const [showAdd, setShowAdd] = useState(false)
  const [name, setName] = useState('')
  const [saving, setSaving] = useState(false)
  const addRef = useRef<HTMLDivElement>(null)

  const headers = { Authorization: `Bearer ${token}` }

  const fetchFolders = useCallback(async () => {
    try {
      const res = await fetch(`${API_URL}/folders`, { headers })
      if (res.ok) {
        const data = await res.json()
        setFolders(Array.isArray(data) ? data.map((f: SidebarFolder) => ({ id: f.id, name: f.name })) : [])
      }
    } catch (_) {}
  }, [token])

  useEffect(() => { fetchFolders() }, [fetchFolders])

  useEffect(() => {
    if (!showAdd) return
    const handler = (e: MouseEvent) => {
      if (addRef.current && !addRef.current.contains(e.target as Node)) {
        setShowAdd(false)
        setName('')
      }
    }
    document.addEventListener('mousedown', handler)
    return () => document.removeEventListener('mousedown', handler)
  }, [showAdd])

  const handleCreate = async () => {
    const trimmed = name.trim()
    if (!trimmed) return
    setSaving(true)
    try {
      const res = await fetch(`${API_URL}/folders`, {
        method: 'POST',
        headers: { ...headers, 'Content-Type': 'application/json' },
        body: JSON.stringify({ name: trimmed, description: '' }),
      })
      if (res.ok) {
        setName('')
        setShowAdd(false)
        await fetchFolders()
      }
    } finally {
      setSaving(false)
    }
  }

  const params = new URLSearchParams(activePath.split('?')[1] ?? '')
  const activeFolderId = params.get('folder')

  return (
    <div className="sidebar-folder-section">
      <div className="sidebar-folder-divider" />

      <div className="sidebar-folder-add" ref={addRef}>
        <button
          className="nav-item"
          title="New folder"
          onClick={() => setShowAdd((p) => !p)}
        >
          <span className="nav-icon">＋</span>
        </button>

        {showAdd && (
          <div className="folder-add-popup">
            <p className="folder-add-popup-label">New folder</p>
            <input
              autoFocus
              placeholder="Folder name"
              value={name}
              onChange={(e) => setName(e.target.value)}
              onKeyDown={(e) => { if (e.key === 'Enter') handleCreate() }}
            />
            <button onClick={handleCreate} disabled={saving || !name.trim()}>
              {saving ? '…' : 'Create'}
            </button>
          </div>
        )}
      </div>

      {folders.map((f) => (
        <button
          key={f.id}
          className={`nav-item${activeFolderId === f.id ? ' active' : ''}`}
          title={f.name}
          onClick={() => onNavigate(`/learner/folders?folder=${f.id}`)}
        >
          <span className="nav-icon">📁</span>
        </button>
      ))}
    </div>
  )
}

interface SidebarProps {
  menuItems: MenuItem[]
  activePath: string
  userName: string
  onNavigate: (path: string) => void
  onLogout: () => void
  folderSection?: { token: string; activePath: string; onNavigate: (path: string) => void }
}

function getInitials(name: string): string {
  return name
    .split(' ')
    .filter(Boolean)
    .slice(0, 2)
    .map((w) => w[0].toUpperCase())
    .join('')
}

export default function Sidebar({ menuItems, activePath, userName, onNavigate, onLogout, folderSection }: SidebarProps) {
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

      {folderSection && (
        <FolderSection
          token={folderSection.token}
          activePath={folderSection.activePath}
          onNavigate={folderSection.onNavigate}
        />
      )}

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
