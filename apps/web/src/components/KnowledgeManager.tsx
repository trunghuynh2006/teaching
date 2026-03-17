import { useCallback, useEffect, useState } from 'react'
import { API_URL } from '../config'

interface SourceItem {
  id: string
  folder_id: string
  title?: string
  content: string
  created_by?: string
  updated_by?: string
  created_time?: string
  updated_time?: string
}

interface KnowledgeManagerProps {
  folderId: string
  token: string
  onUnauthorized?: () => void
  onCountChange?: (count: number) => void
  addTrigger?: number
}

interface FormState {
  title: string
  content: string
}

const DEFAULT_FORM: FormState = { title: '', content: '' }

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

export default function KnowledgeManager({ folderId, token, onUnauthorized, onCountChange, addTrigger }: KnowledgeManagerProps) {
  const [sources, setSources] = useState<SourceItem[]>([])
  const [editingItem, setEditingItem] = useState<SourceItem | null>(null)
  const [form, setForm] = useState<FormState>(DEFAULT_FORM)
  const [showForm, setShowForm] = useState(false)
  const [loading, setLoading] = useState(false)
  const [saving, setSaving] = useState(false)
  const [error, setError] = useState('')
  const [notice, setNotice] = useState('')

  const headers = { Authorization: `Bearer ${token}` }

  const fetchSources = useCallback(async () => {
    setLoading(true)
    setError('')
    try {
      const res = await fetch(`${API_URL}/folders/${folderId}/sources`, { headers })
      if (res.status === 401) { onUnauthorized?.(); return }
      if (!res.ok) throw new Error(await parseError(res))
      const data = await res.json()
      const items: SourceItem[] = Array.isArray(data) ? data : []
      setSources(items)
      onCountChange?.(items.length)
    } catch (err) {
      setError((err as Error).message || 'Failed to load sources')
    } finally {
      setLoading(false)
    }
  }, [folderId, token, onUnauthorized])

  useEffect(() => { fetchSources() }, [fetchSources])

  useEffect(() => {
    if (addTrigger) {
      setEditingItem(null)
      setForm(DEFAULT_FORM)
      setShowForm(true)
      setNotice('')
      setError('')
    }
  }, [addTrigger])

  const openEditForm = (item: SourceItem) => {
    setEditingItem(item)
    setForm({ title: item.title ?? '', content: item.content })
    setShowForm(true)
    setNotice('')
    setError('')
  }

  const cancelForm = () => {
    setShowForm(false)
    setEditingItem(null)
    setForm(DEFAULT_FORM)
  }

  const handleSubmit = async (event: React.FormEvent) => {
    event.preventDefault()
    setError('')
    setNotice('')
    const content = form.content.trim()
    if (!content) { setError('Content is required'); return }
    setSaving(true)
    try {
      const url = editingItem
        ? `${API_URL}/sources/${editingItem.id}`
        : `${API_URL}/folders/${folderId}/sources`
      const method = editingItem ? 'PUT' : 'POST'
      const res = await fetch(url, {
        method,
        headers: { ...headers, 'Content-Type': 'application/json' },
        body: JSON.stringify({ title: form.title.trim(), content }),
      })
      if (res.status === 401) { onUnauthorized?.(); return }
      if (!res.ok) throw new Error(await parseError(res))
      setNotice(editingItem ? 'Updated' : 'Created')
      cancelForm()
      await fetchSources()
    } catch (err) {
      setError((err as Error).message || 'Failed to save source')
    } finally {
      setSaving(false)
    }
  }

  const handleDelete = async (item: SourceItem) => {
    const label = item.title || item.content.slice(0, 40)
    if (!window.confirm(`Delete "${label}"?`)) return
    setError('')
    setNotice('')
    try {
      const res = await fetch(`${API_URL}/sources/${item.id}`, { method: 'DELETE', headers })
      if (res.status === 401) { onUnauthorized?.(); return }
      if (!res.ok) throw new Error(await parseError(res))
      setNotice('Deleted')
      await fetchSources()
    } catch (err) {
      setError((err as Error).message || 'Failed to delete source')
    }
  }

  return (
    <div className="knowledge-manager">
      {notice && <div className="notice">{notice}</div>}
      {error && <div className="error">{error}</div>}

      {showForm && (
        <form className="skill-form" onSubmit={handleSubmit}>
          <label>
            Title (optional)
            <input
              autoFocus
              value={form.title}
              onChange={(e) => setForm((prev) => ({ ...prev, title: e.target.value }))}
              placeholder="e.g. Definition of velocity"
            />
          </label>
          <label>
            Content
            <textarea
              className="knowledge-textarea"
              value={form.content}
              onChange={(e) => setForm((prev) => ({ ...prev, content: e.target.value }))}
              placeholder="Write the source content here…"
              required
            />
          </label>
          <div className="skill-actions">
            <button type="submit" disabled={saving}>
              {saving ? 'Saving…' : editingItem ? 'Update' : 'Create'}
            </button>
            <button type="button" className="secondary" onClick={cancelForm}>Cancel</button>
          </div>
        </form>
      )}

      <div className="knowledge-list">
        {sources.length === 0 && !loading && !showForm ? (
          <p className="knowledge-empty">No entries yet.</p>
        ) : (
          sources.map((item) => (
            <article className="knowledge-item" key={item.id}>
              {item.title && <h5 className="knowledge-title">{item.title}</h5>}
              <p className="knowledge-content">{item.content}</p>
              <div className="knowledge-meta">
                <span>By: {item.created_by || '-'}</span>
                <span>Created: {formatDate(item.created_time)}</span>
                {item.updated_time !== item.created_time && (
                  <span>Updated: {formatDate(item.updated_time)}</span>
                )}
              </div>
              <div className="skill-actions">
                <button type="button" className="secondary" onClick={() => openEditForm(item)}>Edit</button>
                <button type="button" className="secondary" onClick={() => handleDelete(item)}>Delete</button>
              </div>
            </article>
          ))
        )}
      </div>
    </div>
  )
}
