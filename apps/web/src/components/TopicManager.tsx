import { useCallback, useEffect, useState } from 'react'
import { API_URL } from '../config'

interface TopicItem {
  id: string
  name: string
  folder_id: string
  description?: string
  created_by?: string
  created_time?: string
  updated_time?: string
}

interface TopicManagerProps {
  folderId: string
  token: string
  onUnauthorized?: () => void
  onCountChange?: (count: number) => void
  addTrigger?: number
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

export default function TopicManager({ folderId, token, onUnauthorized, onCountChange, addTrigger }: TopicManagerProps) {
  const [topics, setTopics] = useState<TopicItem[]>([])
  const [editingItem, setEditingItem] = useState<TopicItem | null>(null)
  const [form, setForm] = useState<FormState>(DEFAULT_FORM)
  const [showForm, setShowForm] = useState(false)
  const [loading, setLoading] = useState(false)
  const [saving, setSaving] = useState(false)
  const [error, setError] = useState('')
  const [notice, setNotice] = useState('')

  const headers = { Authorization: `Bearer ${token}` }

  const fetchTopics = useCallback(async () => {
    setLoading(true)
    setError('')
    try {
      const res = await fetch(`${API_URL}/folders/${folderId}/topics`, { headers })
      if (res.status === 401) { onUnauthorized?.(); return }
      if (!res.ok) throw new Error(await parseError(res))
      const data = await res.json()
      const items: TopicItem[] = Array.isArray(data) ? data : []
      setTopics(items)
      onCountChange?.(items.length)
    } catch (err) {
      setError((err as Error).message || 'Failed to load topics')
    } finally {
      setLoading(false)
    }
  }, [folderId, token, onUnauthorized])

  useEffect(() => { fetchTopics() }, [fetchTopics])

  useEffect(() => {
    if (addTrigger) {
      setEditingItem(null)
      setForm(DEFAULT_FORM)
      setShowForm(true)
      setNotice('')
      setError('')
    }
  }, [addTrigger])

  const openEditForm = (item: TopicItem) => {
    setEditingItem(item)
    setForm({ name: item.name, description: item.description ?? '' })
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
    const name = form.name.trim()
    if (!name) { setError('Name is required'); return }
    setSaving(true)
    try {
      const url = editingItem
        ? `${API_URL}/topics/${editingItem.id}`
        : `${API_URL}/folders/${folderId}/topics`
      const method = editingItem ? 'PUT' : 'POST'
      const res = await fetch(url, {
        method,
        headers: { ...headers, 'Content-Type': 'application/json' },
        body: JSON.stringify({ name, description: form.description.trim() }),
      })
      if (res.status === 401) { onUnauthorized?.(); return }
      if (!res.ok) throw new Error(await parseError(res))
      setNotice(editingItem ? 'Updated' : 'Created')
      cancelForm()
      await fetchTopics()
    } catch (err) {
      setError((err as Error).message || 'Failed to save topic')
    } finally {
      setSaving(false)
    }
  }

  const handleDelete = async (item: TopicItem) => {
    if (!window.confirm(`Delete topic "${item.name}"?`)) return
    setError('')
    setNotice('')
    try {
      const res = await fetch(`${API_URL}/topics/${item.id}`, { method: 'DELETE', headers })
      if (res.status === 401) { onUnauthorized?.(); return }
      if (!res.ok) throw new Error(await parseError(res))
      setNotice('Deleted')
      await fetchTopics()
    } catch (err) {
      setError((err as Error).message || 'Failed to delete topic')
    }
  }

  return (
    <div className="knowledge-manager">
      {notice && <div className="notice">{notice}</div>}
      {error && <div className="error">{error}</div>}

      {showForm && (
        <form className="skill-form" onSubmit={handleSubmit}>
          <label>
            Name
            <input
              autoFocus
              required
              value={form.name}
              onChange={(e) => setForm((prev) => ({ ...prev, name: e.target.value }))}
              placeholder="e.g. Email Structure"
            />
          </label>
          <label>
            Description (optional)
            <input
              value={form.description}
              onChange={(e) => setForm((prev) => ({ ...prev, description: e.target.value }))}
              placeholder="Short description of this topic"
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
        {topics.length === 0 && !loading && !showForm ? (
          <p className="knowledge-empty">No topics yet.</p>
        ) : (
          topics.map((item) => (
            <article className="knowledge-item" key={item.id}>
              <h5 className="knowledge-title">{item.name}</h5>
              {item.description && <p className="knowledge-content">{item.description}</p>}
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
