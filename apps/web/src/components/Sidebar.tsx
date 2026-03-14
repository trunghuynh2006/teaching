import { useCallback, useEffect, useRef, useState } from 'react'
import { API_URL } from '../config'
import { MenuItem } from '../config/menu'
import { FolderIconDisplay } from '../config/folderIcons'
import IconPicker from './IconPicker'

interface FolderSectionProps {
  token: string
  activePath: string
  onNavigate: (path: string) => void
}

interface SidebarFolder {
  id: string
  name: string
  icon?: string
  theme?: string
}

const FOLDER_THEMES = ['', 'blue', 'green', 'purple', 'orange', 'red', 'teal', 'gray']

function FolderSection({ token, activePath, onNavigate }: FolderSectionProps) {
  const [folders, setFolders] = useState<SidebarFolder[]>([])
  const [showAdd, setShowAdd] = useState(false)
  const [name, setName] = useState('')
  const [description, setDescription] = useState('')
  const [theme, setTheme] = useState('')
  const [icon, setIcon] = useState('')
  const [saving, setSaving] = useState(false)

  const headers = { Authorization: `Bearer ${token}` }

  const fetchFolders = useCallback(async () => {
    try {
      const res = await fetch(`${API_URL}/folders`, { headers })
      if (res.ok) {
        const data = await res.json()
        setFolders(Array.isArray(data) ? data.map((f: SidebarFolder) => ({ id: f.id, name: f.name, icon: f.icon, theme: f.theme })) : [])
      }
    } catch (_) {}
  }, [token])

  useEffect(() => { fetchFolders() }, [fetchFolders])

  const resetForm = () => { setName(''); setDescription(''); setTheme(''); setIcon('') }

  const handleClose = () => { setShowAdd(false); resetForm() }

  const handleCreate = async (e: React.FormEvent) => {
    e.preventDefault()
    const trimmed = name.trim()
    if (!trimmed) return
    setSaving(true)
    try {
      const res = await fetch(`${API_URL}/folders`, {
        method: 'POST',
        headers: { ...headers, 'Content-Type': 'application/json' },
        body: JSON.stringify({ name: trimmed, description: description.trim(), theme, icon: icon.trim() }),
      })
      if (res.ok) {
        handleClose()
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

      <div className="sidebar-folder-add">
        <button
          className="nav-item"
          title="New folder"
          onClick={() => setShowAdd(true)}
        >
          <span className="nav-icon">＋</span>
        </button>
      </div>

      {folders.map((f) => (
        <button
          key={f.id}
          className={`nav-item${activeFolderId === f.id ? ' active' : ''}`}
          title={f.name}
          onClick={() => onNavigate(`/learner/folders?folder=${f.id}`)}
        >
          <span className="nav-icon"><FolderIconDisplay value={f.icon} size={18} /></span>
        </button>
      ))}

      {showAdd && (
        <div className="folder-create-modal-overlay" onClick={handleClose}>
          <div className="folder-create-modal" onClick={(e) => e.stopPropagation()}>
            <div className="folder-create-modal-header">
              <span>New Folder</span>
              <button className="modal-close" onClick={handleClose}>✕</button>
            </div>
            <form className="folder-create-modal-body" onSubmit={handleCreate}>
              <label>
                Name
                <input
                  autoFocus
                  required
                  placeholder="e.g. Algebra Unit 1"
                  value={name}
                  onChange={(e) => setName(e.target.value)}
                />
              </label>
              <label>
                Description
                <input
                  placeholder="Optional description"
                  value={description}
                  onChange={(e) => setDescription(e.target.value)}
                />
              </label>
              <label>
                Theme
                <select value={theme} onChange={(e) => setTheme(e.target.value)}>
                  <option value="">— none —</option>
                  {FOLDER_THEMES.map((t) => <option key={t} value={t}>{t}</option>)}
                </select>
              </label>
              <label>
                Icon
                <IconPicker value={icon} onChange={setIcon} />
              </label>
              <div className="folder-create-modal-actions">
                <button type="submit" disabled={saving || !name.trim()}>
                  {saving ? 'Creating…' : 'Create Folder'}
                </button>
                <button type="button" className="secondary" onClick={handleClose}>Cancel</button>
              </div>
            </form>
          </div>
        </div>
      )}
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
