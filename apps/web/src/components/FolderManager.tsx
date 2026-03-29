import { useCallback, useEffect, useState } from 'react'
import { useSearchParams } from 'react-router-dom'
import { API_URL } from '../config'
import { FolderIconDisplay } from '../config/folderIcons'
import IconPicker from './IconPicker'
import KnowledgeManager from './KnowledgeManager'
import TopicManager from './TopicManager'
import SpaceManager from './SpaceManager'
import SpaceItemsSidebar from './SpaceItemsSidebar'
import ProblemDetail from './ProblemDetail'
import QuestionDetail from './QuestionDetail'
import AnkiDetail from './AnkiDetail'
import QuestionModal from './QuestionModal'
import AnkiModal from './AnkiModal'
import AnkiGenerateModal from './AnkiGenerateModal'

interface FolderItem {
  id: string
  name: string
  description?: string
  domain?: string
  theme?: string
  icon?: string
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
  domain: string
  theme: string
  icon: string
}

const DEFAULT_FORM: FormState = { name: '', description: '', domain: '', theme: '', icon: '' }

const FOLDER_THEMES = ['', 'blue', 'green', 'purple', 'orange', 'red', 'teal', 'gray']

const POPULAR_DOMAINS = [
  'mathematics',
  'physics',
  'chemistry',
  'biology',
  'computer-science',
  'history',
  'geography',
  'literature',
  'economics',
  'psychology',
  'philosophy',
  'linguistics',
  'engineering',
  'medicine',
  'law',
  'business',
  'art',
  'music',
]

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
  Anki: '⟳',
  Note: '≡',
  Quiz: '★',
  Other: '•',
}
const spaceTypeIcon = (t?: string) => (t ? (SPACE_TYPE_ICONS[t] ?? '•') : '')

type FolderSection = 'knowledge' | 'topics' | 'spaces'

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
  const [topicsCount, setTopicsCount] = useState(0)
  const [topicsAddTrigger, setTopicsAddTrigger] = useState(0)
  const [spacesCount, setSpacesCount] = useState(0)
  const [showSpaceModal, setShowSpaceModal] = useState(false)
  const [spaceModalName, setSpaceModalName] = useState('')
  const [spaceModalType, setSpaceModalType] = useState('')
  const [spaceModalDesc, setSpaceModalDesc] = useState('')
  const [spaceModalSaving, setSpaceModalSaving] = useState(false)
  const [spaceModalError, setSpaceModalError] = useState('')
  const [sidebarSpaces, setSidebarSpaces] = useState<SidebarSpace[]>([])
  const [selectedSpace, setSelectedSpace] = useState<SidebarSpace | null>(null)
  // refreshKey is incremented when a new item is added, to re-trigger detail fetches
  const [detailRefreshKey, setDetailRefreshKey] = useState(0)
  const [selectedItemId, setSelectedItemId] = useState<string | null>(null)
  const [showInlineQuestionModal, setShowInlineQuestionModal] = useState(false)
  const [showInlineAnkiModal, setShowInlineAnkiModal] = useState(false)
  const [showAnkiGenerateModal, setShowAnkiGenerateModal] = useState(false)
  const [form, setForm] = useState<FormState>(DEFAULT_FORM)
  const [editingId, setEditingId] = useState('')
  const [showForm, setShowForm] = useState(false)
  const [loading, setLoading] = useState(false)
  const [saving, setSaving] = useState(false)
  const [error, setError] = useState('')
  const [notice, setNotice] = useState('')

  const headers = { Authorization: `Bearer ${token}` }

  const isDetailSpace = (s: SidebarSpace) =>
    s.space_type === 'Problem' || s.space_type === 'Exercise' || s.space_type === 'Question' || s.space_type === 'Anki'

  const isProblemOrExercise = (s: SidebarSpace) =>
    s.space_type === 'Problem' || s.space_type === 'Exercise'

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
    setForm({ name: folder.name, description: folder.description ?? '', domain: folder.domain ?? '', theme: folder.theme ?? '', icon: folder.icon ?? '' })
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
        body: JSON.stringify({ name, description: form.description.trim(), domain: form.domain, theme: form.theme, icon: form.icon.trim() }),
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
    setTopicsCount(0)
    setSpacesCount(0)
    setSidebarSpaces([])
    setSelectedSpace(null)
    setError('')
    setNotice('')
    fetchSidebarSpaces(folder.id)
  }

  // Keep sidebar spaces in sync when spaces are added/removed
  useEffect(() => {
    if (selectedFolder) fetchSidebarSpaces(selectedFolder.id)
  }, [spacesCount])

  const SPACE_TYPES = ['Problem', 'Exercise', 'Question', 'Anki', 'Note', 'Quiz', 'Other']

  const openSpaceModal = () => {
    setSpaceModalName('')
    setSpaceModalType('')
    setSpaceModalDesc('')
    setSpaceModalError('')
    setShowSpaceModal(true)
    setActiveSection('spaces')
  }

  const closeSpaceModal = () => {
    setShowSpaceModal(false)
  }

  const handleSpaceModalSubmit = async (e: React.FormEvent) => {
    e.preventDefault()
    if (!selectedFolder) return
    const name = spaceModalName.trim()
    if (!name) { setSpaceModalError('Name is required'); return }
    setSpaceModalSaving(true)
    setSpaceModalError('')
    try {
      const res = await fetch(`${API_URL}/folders/${selectedFolder.id}/spaces`, {
        method: 'POST',
        headers: { ...headers, 'Content-Type': 'application/json' },
        body: JSON.stringify({ name, space_type: spaceModalType, description: spaceModalDesc.trim() }),
      })
      if (res.status === 401) { onUnauthorized?.(); return }
      if (!res.ok) {
        const p = await res.json().catch(() => ({}))
        throw new Error(p?.detail || 'Failed to create space')
      }
      const newSpace: SidebarSpace = await res.json()
      closeSpaceModal()
      await fetchSidebarSpaces(selectedFolder.id)
      setSelectedSpace(newSpace)
      setActiveSection('spaces')
    } catch (err) {
      setSpaceModalError((err as Error).message)
    } finally {
      setSpaceModalSaving(false)
    }
  }

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
            <label>
              Domain
              <select value={form.domain} onChange={(e) => setForm((prev) => ({ ...prev, domain: e.target.value }))}>
                <option value="">— none —</option>
                {POPULAR_DOMAINS.map((d) => <option key={d} value={d}>{d}</option>)}
              </select>
            </label>
            <label>
              Theme
              <select value={form.theme} onChange={(e) => setForm((prev) => ({ ...prev, theme: e.target.value }))}>
                <option value="">— none —</option>
                {FOLDER_THEMES.filter(Boolean).map((t) => <option key={t} value={t}>{t}</option>)}
              </select>
            </label>
            <label>
              Icon
              <IconPicker value={form.icon} onChange={(v) => setForm((prev) => ({ ...prev, icon: v }))} />
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
              <article className={`skill-item${folder.theme ? ` folder-theme-${folder.theme}` : ''}`} key={folder.id}>
                <header>
                  {folder.icon && <span className="folder-icon"><FolderIconDisplay value={folder.icon} size={18} /></span>}
                  <h4>{folder.name}</h4>
                </header>
                {folder.description && <p>{folder.description}</p>}
                <div className="skill-meta">
                  {folder.domain && <span>Domain: {folder.domain}</span>}
                  {folder.theme && <span>Theme: {folder.theme}</span>}
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

        {/* Topics nav item */}
        <button
          className={`folder-sidebar-item${activeSection === 'topics' ? ' active' : ''}`}
          onClick={() => { setActiveSection('topics'); setSelectedSpace(null) }}
        >
          <span>Topics</span>
          <div className="folder-sidebar-item-end">
            <span className="folder-sidebar-count">{topicsCount}</span>
            <button
              className="folder-sidebar-add-btn"
              title="Add topic"
              onClick={(e) => { e.stopPropagation(); setActiveSection('topics'); setTopicsAddTrigger((n) => n + 1) }}
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
            onClick={openSpaceModal}
          >
            +
          </button>
        </div>

        {/* List of spaces */}
        {sidebarSpaces.map((space) => (
          <button
            key={space.id}
            className={`folder-sidebar-space-item${selectedSpace?.id === space.id ? ' active' : ''}`}
            onClick={() => { setSelectedSpace(space); setActiveSection('spaces'); setSelectedItemId(null) }}
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
      {selectedSpace && isProblemOrExercise(selectedSpace) && (
        <>
          <SpaceItemsSidebar
            space={selectedSpace}
            token={token}
            onUnauthorized={onUnauthorized}
            onAdded={() => setDetailRefreshKey((k) => k + 1)}
            selectedItemId={selectedItemId}
            onSelectItem={setSelectedItemId}
            refreshKey={detailRefreshKey}
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
        {activeSection === 'topics' && (
          <TopicManager
            folderId={selectedFolder.id}
            token={token}
            onUnauthorized={onUnauthorized}
            onCountChange={setTopicsCount}
            addTrigger={topicsAddTrigger}
          />
        )}
        {activeSection === 'spaces' && selectedSpace && isDetailSpace(selectedSpace) && (
          selectedSpace.space_type === 'Problem' ? (
            <ProblemDetail
              key={`${selectedSpace.id}-${selectedItemId}-${detailRefreshKey}`}
              spaceId={selectedSpace.id}
              token={token}
              onUnauthorized={onUnauthorized}
              problemId={selectedItemId}
            />
          ) : selectedSpace.space_type === 'Question' ? (
            <>
              <div className="folder-content-actions">
                <button onClick={() => setShowInlineQuestionModal(true)}>+ New Question</button>
              </div>
              <QuestionDetail
                key={`${selectedSpace.id}-${detailRefreshKey}`}
                spaceId={selectedSpace.id}
                token={token}
                onUnauthorized={onUnauthorized}
              />
              {showInlineQuestionModal && (
                <QuestionModal
                  space={selectedSpace}
                  token={token}
                  onUnauthorized={onUnauthorized}
                  onSaved={() => { setShowInlineQuestionModal(false); setDetailRefreshKey((k) => k + 1) }}
                  onClose={() => setShowInlineQuestionModal(false)}
                />
              )}
            </>
          ) : selectedSpace.space_type === 'Anki' ? (
            <>
              <div className="folder-content-actions">
                <button onClick={() => setShowInlineAnkiModal(true)}>+ New Card</button>
                <button className="secondary" onClick={() => setShowAnkiGenerateModal(true)}>Generate from Knowledge</button>
              </div>
              <AnkiDetail
                key={`${selectedSpace.id}-${detailRefreshKey}`}
                spaceId={selectedSpace.id}
                token={token}
                onUnauthorized={onUnauthorized}
              />
              {showInlineAnkiModal && (
                <AnkiModal
                  space={selectedSpace}
                  token={token}
                  onUnauthorized={onUnauthorized}
                  onSaved={() => { setShowInlineAnkiModal(false); setDetailRefreshKey((k) => k + 1) }}
                  onClose={() => setShowInlineAnkiModal(false)}
                />
              )}
              {showAnkiGenerateModal && selectedFolder && (
                <AnkiGenerateModal
                  spaceId={selectedSpace.id}
                  folderId={selectedFolder.id}
                  token={token}
                  onUnauthorized={onUnauthorized}
                  onSaved={() => { setShowAnkiGenerateModal(false); setDetailRefreshKey((k) => k + 1) }}
                  onClose={() => setShowAnkiGenerateModal(false)}
                />
              )}
            </>
          ) : null
        )}
        {activeSection === 'spaces' && (!selectedSpace || !isDetailSpace(selectedSpace)) && (
          <SpaceManager
            folderId={selectedFolder.id}
            token={token}
            onUnauthorized={onUnauthorized}
            onCountChange={setSpacesCount}
            filterSpaceId={selectedSpace?.id}
          />
        )}
      </div>

      {showSpaceModal && (
        <div className="folder-create-modal-overlay" onClick={closeSpaceModal}>
          <div className="folder-create-modal" onClick={(e) => e.stopPropagation()}>
            <div className="folder-create-modal-header">
              <span>New Space</span>
              <button className="modal-close" onClick={closeSpaceModal}>✕</button>
            </div>
            <form className="folder-create-modal-body" onSubmit={handleSpaceModalSubmit}>
              {spaceModalError && <div className="error">{spaceModalError}</div>}
              <label>
                Name
                <input
                  autoFocus
                  required
                  placeholder="e.g. Problem Set 1"
                  value={spaceModalName}
                  onChange={(e) => setSpaceModalName(e.target.value)}
                />
              </label>
              <label>
                Type
                <select value={spaceModalType} onChange={(e) => setSpaceModalType(e.target.value)}>
                  <option value="">— select type —</option>
                  {SPACE_TYPES.map((t) => <option key={t} value={t}>{t}</option>)}
                </select>
              </label>
              <label>
                Description (optional)
                <input
                  placeholder="Short description"
                  value={spaceModalDesc}
                  onChange={(e) => setSpaceModalDesc(e.target.value)}
                />
              </label>
              <div className="folder-create-modal-actions">
                <button type="submit" disabled={spaceModalSaving}>
                  {spaceModalSaving ? 'Creating…' : 'Create Space'}
                </button>
                <button type="button" className="secondary" onClick={closeSpaceModal}>Cancel</button>
              </div>
            </form>
          </div>
        </div>
      )}
    </section>
  )
}
