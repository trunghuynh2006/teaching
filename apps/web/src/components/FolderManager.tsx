import { useCallback, useEffect, useState } from 'react'
import { useSearchParams } from 'react-router-dom'
import { API_URL } from '../config'
import KnowledgeManager from './KnowledgeManager'
import SpaceManager from './SpaceManager'
import SpaceItemsSidebar, { type SpaceItemData } from './SpaceItemsSidebar'
import ProblemDetail from './ProblemDetail'
import QuestionDetail from './QuestionDetail'

interface FolderItem {
  id: string
  name: string
  description?: string
  created_by?: string
  updated_by?: string
  created_time?: string
  updated_time?: string
}

interface FolderManagerProps {
  token: string
  onUnauthorized?: () => void
}

interface FormState {
  name: string
  description: string
}

const DEFAULT_FORM: FormState = { name: '', description: '' }

async function parseError(response: Response): Promise<string> {
  try {
    const payload = await response.json()
    if (payload?.detail) return payload.detail
  } catch (_) {}
  return response.statusText || 'Request failed'
}

function formatDate(dateTime: string | undefined): string {
  if (!dateTime) return '-'
  const parsed = new Date(dateTime)
  if (Number.isNaN(parsed.getTime())) return dateTime
  return parsed.toLocaleString()
}

const SPACE_TYPE_ICONS: Record<string, string> = {
  Problem: 'Σ',
  Exercise: '✎',
  Question: '?',
  Note: '≡',
  Quiz: '★',
  Other: '•',
}
const spaceTypeIcon = (t?: string) => (t ? (SPACE_TYPE_ICONS[t] ?? '•') : '')

type FolderSection = 'knowledge' | 'spaces'

interface SidebarSpace {
  id: string
  name: string
  space_type?: string
}

export default function FolderManager({ token, onUnauthorized }: FolderManagerProps) {
  const [searchParams] = useSearchParams()
  const [folders, setFolders] = useState<FolderItem[]>([])
  const [selectedFolder, setSelectedFolder] = useState<FolderItem | null>(null)
  const [activeSection, setActiveSection] = useState<FolderSection>('knowledge')
  const [knowledgeCount, setKnowledgeCount] = useState(0)
  const [knowledgeAddTrigger, setKnowledgeAddTrigger] = useState(0)
  const [spacesCount, setSpacesCount] = useState(0)
  const [spacesAddTrigger, setSpacesAddTrigger] = useState(0)
  const [sidebarSpaces, setSidebarSpaces] = useState<SidebarSpace[]>([])
  const [selectedSpace, setSelectedSpace] = useState<SidebarSpace | null>(null)
  const [selectedSpaceItem, setSelectedSpaceItem] = useState<SpaceItemData | null>(null)
  const [form, setForm] = useState<FormState>(DEFAULT_FORM)
  const [editingId, setEditingId] = useState('')
  const [showForm, setShowForm] = useState(false)
  const [loading, setLoading] = useState(false)
  const [saving, setSaving] = useState(false)
  const [error, setError] = useState('')
  const [notice, setNotice] = useState('')

  const headers = { Authorization: `Bearer ${token}` }

  const isDetailSpace = (s: SidebarSpace) =>
    s.space_type === 'Problem' || s.space_type === 'Exercise' || s.space_type === 'Question'

  const fetchFolders = useCallback(async () => {
    setLoading(true)
    setError('')
    try {
      const res = await fetch(`${API_URL}/folders`, { headers })
      if (res.status === 401) { onUnauthorized?.(); return }
      if (!res.ok) throw new Error(await parseError(res))
      const data = await res.json()
      setFolders(Array.isArray(data) ? data : [])
    } catch (err) {
      setError((err as Error).message || 'Failed to load folders')
    } finally {
      setLoading(false)
    }
  }, [token, onUnauthorized])

  useEffect(() => { fetchFolders() }, [fetchFolders])

  const fetchSidebarSpaces = useCallback(async (folderId: string) => {
    try {
      const res = await fetch(`${API_URL}/folders/${folderId}/spaces`, { headers })
      if (res.ok) {
        const data = await res.json()
        setSidebarSpaces(Array.isArray(data) ? data : [])
      }
    } catch (_) {}
  }, [token])

  const openCreateForm = () => {
    setEditingId('')
    setForm(DEFAULT_FORM)
    setShowForm(true)
    setNotice('')
    setError('')
  }

  const openEditForm = (folder: FolderItem) => {
    setEditingId(folder.id)
    setForm({ name: folder.name, description: folder.description ?? '' })
    setShowForm(true)
    setNotice('')
    setError('')
  }

  const cancelForm = () => {
    setShowForm(false)
    setEditingId('')
    setForm(DEFAULT_FORM)
  }

  const handleSubmit = async (event: React.FormEvent) => {
    event.preventDefault()
    setError('')
    setNotice('')
    const name = form.name.trim()
    if (!name) { setError('Name is required'); return }
    setSaving(true)
    try {
      const url = editingId ? `${API_URL}/folders/${editingId}` : `${API_URL}/folders`
      const method = editingId ? 'PUT' : 'POST'
      const res = await fetch(url, {
        method,
        headers: { ...headers, 'Content-Type': 'application/json' },
        body: JSON.stringify({ name, description: form.description.trim() }),
      })
      if (res.status === 401) { onUnauthorized?.(); return }
      if (!res.ok) throw new Error(await parseError(res))
      setNotice(editingId ? 'Folder updated' : 'Folder created')
      cancelForm()
      await fetchFolders()
    } catch (err) {
      setError((err as Error).message || 'Failed to save folder')
    } finally {
      setSaving(false)
    }
  }

  const handleDelete = async (folder: FolderItem) => {
    if (!window.confirm(`Delete folder "${folder.name}"?`)) return
    setError('')
    setNotice('')
    try {
      const res = await fetch(`${API_URL}/folders/${folder.id}`, { method: 'DELETE', headers })
      if (res.status === 401) { onUnauthorized?.(); return }
      if (!res.ok) throw new Error(await parseError(res))
      setNotice('Folder deleted')
      if (selectedFolder?.id === folder.id) setSelectedFolder(null)
      await fetchFolders()
    } catch (err) {
      setError((err as Error).message || 'Failed to delete folder')
    }
  }

  const openFolder = (folder: FolderItem) => {
    setSelectedFolder(folder)
    setActiveSection('knowledge')
    setKnowledgeCount(0)
    setSpacesCount(0)
    setSidebarSpaces([])
    setSelectedSpace(null)
    setSelectedSpaceItem(null)
    setError('')
    setNotice('')
    fetchSidebarSpaces(folder.id)
  }

  // Keep sidebar spaces in sync when spaces are added/removed
  useEffect(() => {
    if (selectedFolder) fetchSidebarSpaces(selectedFolder.id)
  }, [spacesCount])

  // Auto-open folder from ?folder= URL param
  const targetFolderId = searchParams.get('folder')
  useEffect(() => {
    if (!targetFolderId || folders.length === 0) return
    const match = folders.find((f) => f.id === targetFolderId)
    if (match && selectedFolder?.id !== targetFolderId) openFolder(match)
  // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [targetFolderId, folders])

  // ── Folder list view ────────────────────────────────────────
  if (!selectedFolder) {
    return (
      <section className="skill-studio">
        <div className="skill-studio-header">
          <h3>Folders</h3>
          <div className="skill-actions compact">
            <button type="button" className="secondary" onClick={fetchFolders} disabled={loading}>
              {loading ? 'Refreshing...' : 'Refresh'}
            </button>
            <button type="button" onClick={openCreateForm}>New Folder</button>
          </div>
        </div>

        {notice && <div className="notice">{notice}</div>}
        {error && <div className="error">{error}</div>}

        {showForm && (
          <form className="skill-form" onSubmit={handleSubmit}>
            <label>
              Name
              <input
                value={form.name}
                onChange={(e) => setForm((prev) => ({ ...prev, name: e.target.value }))}
                placeholder="e.g. Algebra Unit 1"
                required
              />
            </label>
            <label>
              Description
              <input
                value={form.description}
                onChange={(e) => setForm((prev) => ({ ...prev, description: e.target.value }))}
                placeholder="Optional description"
              />
            </label>
            <div className="skill-actions">
              <button type="submit" disabled={saving}>
                {saving ? 'Saving...' : editingId ? 'Update Folder' : 'Create Folder'}
              </button>
              <button type="button" className="secondary" onClick={cancelForm}>Cancel</button>
            </div>
          </form>
        )}

        <div className="skill-list">
          {folders.length === 0 && !loading ? (
            <p>No folders yet. Use "New Folder" to create one.</p>
          ) : (
            folders.map((folder) => (
              <article className="skill-item" key={folder.id}>
                <header>
                  <h4>{folder.name}</h4>
                </header>
                {folder.description && <p>{folder.description}</p>}
                <div className="skill-meta">
                  <span>Created by: {folder.created_by || '-'}</span>
                  <span>Created: {formatDate(folder.created_time)}</span>
                  <span>Updated: {formatDate(folder.updated_time)}</span>
                </div>
                <div className="skill-actions">
                  <button type="button" onClick={() => openFolder(folder)}>Open</button>
                  <button type="button" className="secondary" onClick={() => openEditForm(folder)}>Edit</button>
                  <button type="button" className="secondary" onClick={() => handleDelete(folder)}>Delete</button>
                </div>
              </article>
            ))
          )}
        </div>
      </section>
    )
  }

  // ── Folder detail view ──────────────────────────────────────
  return (
    <section className="skill-studio folder-view">
      <nav className="folder-sidebar-panel">
        <div className="folder-sidebar-name">{selectedFolder.name}</div>

        {/* Knowledge nav item */}
        <button
          className={`folder-sidebar-item${activeSection === 'knowledge' ? ' active' : ''}`}
          onClick={() => { setActiveSection('knowledge'); setSelectedSpace(null) }}
        >
          <span>Knowledge</span>
          <div className="folder-sidebar-item-end">
            <span className="folder-sidebar-count">{knowledgeCount}</span>
            <button
              className="folder-sidebar-add-btn"
              title="Add knowledge"
              onClick={(e) => { e.stopPropagation(); setKnowledgeAddTrigger((n) => n + 1) }}
            >
              +
            </button>
          </div>
        </button>

        {/* Spaces section title */}
        <div className="folder-sidebar-section-title">
          <span>Spaces</span>
          <button
            className="folder-sidebar-add-btn always-visible"
            title="Add space"
            onClick={() => { setSpacesAddTrigger((n) => n + 1); setActiveSection('spaces'); setSelectedSpace(null); setSelectedSpaceItem(null) }}
          >
            +
          </button>
        </div>

        {/* List of spaces */}
        {sidebarSpaces.map((space) => (
          <button
            key={space.id}
            className={`folder-sidebar-space-item${selectedSpace?.id === space.id ? ' active' : ''}`}
            onClick={() => { setSelectedSpace(space); setSelectedSpaceItem(null); setActiveSection('spaces') }}
          >
            {space.space_type && (
              <span className="space-type-icon" title={space.space_type}>{spaceTypeIcon(space.space_type)}</span>
            )}
            <span className="folder-sidebar-space-name">{space.name}</span>
          </button>
        ))}
        {sidebarSpaces.length === 0 && (
          <span className="folder-sidebar-empty">No spaces</span>
        )}
      </nav>

      <div className="folder-sidebar-divider" />

      {/* Space items sidebar — only for Problem/Exercise spaces */}
      {selectedSpace && isDetailSpace(selectedSpace) && (
        <>
          <SpaceItemsSidebar
            space={selectedSpace}
            token={token}
            onUnauthorized={onUnauthorized}
            selectedItemId={selectedSpaceItem?.id}
            onSelectItem={setSelectedSpaceItem}
          />
          <div className="folder-sidebar-divider" />
        </>
      )}

      <div className="folder-content">
        {activeSection === 'knowledge' && (
          <KnowledgeManager
            folderId={selectedFolder.id}
            token={token}
            onUnauthorized={onUnauthorized}
            onCountChange={setKnowledgeCount}
            addTrigger={knowledgeAddTrigger}
          />
        )}
        {activeSection === 'spaces' && selectedSpace && isDetailSpace(selectedSpace) && (
          selectedSpaceItem ? (
            selectedSpace.space_type === 'Problem' ? (
              <ProblemDetail
                key={selectedSpaceItem.id}
                spaceItemId={selectedSpaceItem.id}
                token={token}
                onUnauthorized={onUnauthorized}
              />
            ) : selectedSpace.space_type === 'Question' ? (
              <QuestionDetail
                key={selectedSpaceItem.id}
                spaceItemId={selectedSpaceItem.id}
                token={token}
                onUnauthorized={onUnauthorized}
              />
            ) : (
              <div className="space-item-detail">
                {selectedSpaceItem.title && <h3 className="space-item-detail-title">{selectedSpaceItem.title}</h3>}
                <p className="space-item-detail-content">{selectedSpaceItem.content}</p>
              </div>
            )
          ) : (
            <div className="space-item-detail">
              <p className="space-item-detail-empty">No items in this space.</p>
            </div>
          )
        )}
        {activeSection === 'spaces' && (!selectedSpace || !isDetailSpace(selectedSpace)) && (
          <SpaceManager
            folderId={selectedFolder.id}
            token={token}
            onUnauthorized={onUnauthorized}
            onCountChange={setSpacesCount}
            addTrigger={spacesAddTrigger}
            filterSpaceId={selectedSpace?.id}
          />
        )}
      </div>
    </section>
  )
}
