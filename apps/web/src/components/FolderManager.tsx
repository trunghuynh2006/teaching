import { useCallback, useEffect, useState } from 'react'
import { useSearchParams } from 'react-router-dom'
import { API_URL } from '../config'
import KnowledgeManager from './KnowledgeManager'

interface FolderItem {
  id: string
  name: string
  description?: string
  created_by?: string
  updated_by?: string
  created_time?: string
  updated_time?: string
}

interface SkillItem {
  id: string
  title: string
  description?: string
  difficulty?: string
  status?: string
  tags?: string[]
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

export default function FolderManager({ token, onUnauthorized }: FolderManagerProps) {
  const [searchParams] = useSearchParams()
  const [folders, setFolders] = useState<FolderItem[]>([])
  const [allSkills, setAllSkills] = useState<SkillItem[]>([])
  const [folderSkills, setFolderSkills] = useState<SkillItem[]>([])
  const [selectedFolder, setSelectedFolder] = useState<FolderItem | null>(null)
  const [form, setForm] = useState<FormState>(DEFAULT_FORM)
  const [editingId, setEditingId] = useState('')
  const [showForm, setShowForm] = useState(false)
  const [loading, setLoading] = useState(false)
  const [saving, setSaving] = useState(false)
  const [error, setError] = useState('')
  const [notice, setNotice] = useState('')

  const headers = { Authorization: `Bearer ${token}` }

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

  const fetchAllSkills = useCallback(async () => {
    try {
      const res = await fetch(`${API_URL}/skills`, { headers })
      if (res.status === 401) { onUnauthorized?.(); return }
      if (!res.ok) return
      const data = await res.json()
      setAllSkills(Array.isArray(data) ? data : [])
    } catch (_) {}
  }, [token, onUnauthorized])

  const fetchFolderSkills = useCallback(async (folderId: string) => {
    try {
      const res = await fetch(`${API_URL}/folders/${folderId}/skills`, { headers })
      if (res.status === 401) { onUnauthorized?.(); return }
      if (!res.ok) return
      const data = await res.json()
      setFolderSkills(Array.isArray(data) ? data : [])
    } catch (_) {}
  }, [token, onUnauthorized])

  useEffect(() => {
    fetchFolders()
    fetchAllSkills()
  }, [fetchFolders, fetchAllSkills])

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
        body: JSON.stringify({ name, description: form.description.trim() })
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
    if (!window.confirm(`Delete folder "${folder.name}"? This will not delete the skills inside.`)) return
    setError('')
    setNotice('')
    try {
      const res = await fetch(`${API_URL}/folders/${folder.id}`, {
        method: 'DELETE',
        headers
      })
      if (res.status === 401) { onUnauthorized?.(); return }
      if (!res.ok) throw new Error(await parseError(res))
      setNotice('Folder deleted')
      if (selectedFolder?.id === folder.id) {
        setSelectedFolder(null)
        setFolderSkills([])
      }
      await fetchFolders()
    } catch (err) {
      setError((err as Error).message || 'Failed to delete folder')
    }
  }

  const openFolder = async (folder: FolderItem) => {
    setSelectedFolder(folder)
    setError('')
    setNotice('')
    await fetchFolderSkills(folder.id)
  }

  // Auto-open folder from ?folder= URL param
  const targetFolderId = searchParams.get('folder')
  useEffect(() => {
    if (!targetFolderId || folders.length === 0) return
    const match = folders.find((f) => f.id === targetFolderId)
    if (match && selectedFolder?.id !== targetFolderId) {
      openFolder(match)
    }
  // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [targetFolderId, folders])

  const closeFolder = () => {
    setSelectedFolder(null)
    setFolderSkills([])
  }

  const handleAddSkill = async (skillId: string) => {
    if (!selectedFolder) return
    setError('')
    try {
      const res = await fetch(`${API_URL}/folders/${selectedFolder.id}/skills/${skillId}`, {
        method: 'POST',
        headers
      })
      if (res.status === 401) { onUnauthorized?.(); return }
      if (!res.ok) throw new Error(await parseError(res))
      await fetchFolderSkills(selectedFolder.id)
    } catch (err) {
      setError((err as Error).message || 'Failed to add skill')
    }
  }

  const handleRemoveSkill = async (skillId: string) => {
    if (!selectedFolder) return
    setError('')
    try {
      const res = await fetch(`${API_URL}/folders/${selectedFolder.id}/skills/${skillId}`, {
        method: 'DELETE',
        headers
      })
      if (res.status === 401) { onUnauthorized?.(); return }
      if (!res.ok) throw new Error(await parseError(res))
      await fetchFolderSkills(selectedFolder.id)
    } catch (err) {
      setError((err as Error).message || 'Failed to remove skill')
    }
  }

  const folderSkillIds = new Set(folderSkills.map((s) => s.id))
  const availableSkills = allSkills.filter((s) => !folderSkillIds.has(s.id))

  return (
    <section className="skill-studio">
      <div className="skill-studio-header">
        <h3>{selectedFolder ? `Folder: ${selectedFolder.name}` : 'Folders'}</h3>
        <div className="skill-actions compact">
          {selectedFolder ? (
            <button type="button" className="secondary" onClick={closeFolder}>
              Back to Folders
            </button>
          ) : (
            <>
              <button type="button" className="secondary" onClick={fetchFolders} disabled={loading}>
                {loading ? 'Refreshing...' : 'Refresh'}
              </button>
              <button type="button" onClick={openCreateForm}>New Folder</button>
            </>
          )}
        </div>
      </div>

      {notice && <div className="notice">{notice}</div>}
      {error && <div className="error">{error}</div>}

      {showForm && !selectedFolder && (
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

      {!selectedFolder && (
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
                  <button type="button" className="secondary" onClick={() => openFolder(folder)}>
                    View Skills
                  </button>
                  <button type="button" onClick={() => openEditForm(folder)}>Edit</button>
                  <button type="button" className="secondary" onClick={() => handleDelete(folder)}>
                    Delete
                  </button>
                </div>
              </article>
            ))
          )}
        </div>
      )}

      {selectedFolder && (
        <div>
          {selectedFolder.description && <p>{selectedFolder.description}</p>}
          <h4>Skills in this folder</h4>
          <div className="skill-list">
            {folderSkills.length === 0 ? (
              <p>No skills in this folder yet.</p>
            ) : (
              folderSkills.map((skill) => (
                <article className="skill-item" key={skill.id}>
                  <header>
                    <h4>{skill.title}</h4>
                    {skill.status && <span className={`pill status-${skill.status}`}>{skill.status}</span>}
                  </header>
                  {skill.description && <p>{skill.description}</p>}
                  <div className="skill-actions">
                    <button type="button" className="secondary" onClick={() => handleRemoveSkill(skill.id)}>
                      Remove from folder
                    </button>
                  </div>
                </article>
              ))
            )}
          </div>

          {availableSkills.length > 0 && (
            <div style={{ marginTop: '1.5rem' }}>
              <h4>Add skill to folder</h4>
              <div className="skill-list">
                {availableSkills.map((skill) => (
                  <article className="skill-item" key={skill.id}>
                    <header>
                      <h4>{skill.title}</h4>
                      {skill.status && <span className={`pill status-${skill.status}`}>{skill.status}</span>}
                    </header>
                    <div className="skill-actions">
                      <button type="button" onClick={() => handleAddSkill(skill.id)}>
                        Add to folder
                      </button>
                    </div>
                  </article>
                ))}
              </div>
            </div>
          )}

          <div className="knowledge-section-divider" />
          <KnowledgeManager folderId={selectedFolder.id} token={token} onUnauthorized={onUnauthorized} />
        </div>
      )}
    </section>
  )
}
