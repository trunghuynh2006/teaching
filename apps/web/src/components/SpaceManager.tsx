import { useCallback, useEffect, useState } from 'react'
import { API_URL } from '../config'

interface SpaceData {
  id: string
  folder_id: string
  name: string
  space_type?: string
  description?: string
  created_by?: string
  created_time?: string
}

interface SpaceItemData {
  id: string
  space_id: string
  title?: string
  content: string
  position?: number
  created_by?: string
  created_time?: string
  updated_time?: string
}

interface SpaceManagerProps {
  folderId: string
  token: string
  onUnauthorized?: () => void
  onCountChange?: (count: number) => void
  addTrigger?: number
  filterSpaceId?: string
}

async function parseError(res: Response): Promise<string> {
  try {
    const p = await res.json()
    if (p?.detail) return p.detail
  } catch (_) {}
  return res.statusText || 'Request failed'
}

// ── Space form ───────────────────────────────────────────────

interface SpaceFormProps {
  initial?: { name: string; space_type: string; description: string }
  onSave: (name: string, spaceType: string, description: string) => Promise<void>
  onCancel: () => void
}

const SPACE_TYPES = ['Problem', 'Exercise', 'Question', 'Anki', 'Note', 'Quiz', 'Other']

function SpaceForm({ initial, onSave, onCancel }: SpaceFormProps) {
  const [name, setName] = useState(initial?.name ?? '')
  const [spaceType, setSpaceType] = useState(initial?.space_type ?? '')
  const [description, setDescription] = useState(initial?.description ?? '')
  const [saving, setSaving] = useState(false)
  const [error, setError] = useState('')

  const handleSubmit = async (e: React.FormEvent) => {
    e.preventDefault()
    if (!name.trim()) { setError('Name is required'); return }
    setSaving(true)
    try {
      await onSave(name.trim(), spaceType.trim(), description.trim())
    } catch (err) {
      setError((err as Error).message)
    } finally {
      setSaving(false)
    }
  }

  return (
    <form className="skill-form" onSubmit={handleSubmit}>
      {error && <div className="error">{error}</div>}
      <label>
        Name
        <input autoFocus value={name} onChange={(e) => setName(e.target.value)} placeholder="e.g. Problem Set 1" required />
      </label>
      <label>
        Type
        <select value={spaceType} onChange={(e) => setSpaceType(e.target.value)}>
          <option value="">— select type —</option>
          {SPACE_TYPES.map((t) => <option key={t} value={t}>{t}</option>)}
        </select>
      </label>
      <label>
        Description (optional)
        <input value={description} onChange={(e) => setDescription(e.target.value)} placeholder="Short description" />
      </label>
      <div className="skill-actions">
        <button type="submit" disabled={saving}>{saving ? 'Saving…' : initial ? 'Update' : 'Create'}</button>
        <button type="button" className="secondary" onClick={onCancel}>Cancel</button>
      </div>
    </form>
  )
}

// ── SpaceItem form ───────────────────────────────────────────

interface SpaceItemFormProps {
  spaceType?: string
  initial?: { title: string; content: string }
  onSave: (title: string, content: string) => Promise<void>
  onCancel: () => void
}

function SpaceItemForm({ spaceType, initial, onSave, onCancel }: SpaceItemFormProps) {
  const [title, setTitle] = useState(initial?.title ?? '')
  const [content, setContent] = useState(initial?.content ?? '')
  const [saving, setSaving] = useState(false)
  const [error, setError] = useState('')

  const handleSubmit = async (e: React.FormEvent) => {
    e.preventDefault()
    setSaving(true)
    try {
      await onSave(title.trim(), content.trim())
    } catch (err) {
      setError((err as Error).message)
    } finally {
      setSaving(false)
    }
  }

  const label = spaceType ? `New ${spaceType}` : 'New Item'

  return (
    <form className="skill-form space-item-form" onSubmit={handleSubmit}>
      {error && <div className="error">{error}</div>}
      <label>
        Title (optional)
        <input autoFocus value={title} onChange={(e) => setTitle(e.target.value)} placeholder={label} />
      </label>
      <label>
        Content
        <textarea
          className="knowledge-textarea"
          value={content}
          onChange={(e) => setContent(e.target.value)}
          placeholder="Enter content here…"
        />
      </label>
      <div className="skill-actions">
        <button type="submit" disabled={saving}>{saving ? 'Saving…' : initial ? 'Update' : 'Create'}</button>
        <button type="button" className="secondary" onClick={onCancel}>Cancel</button>
      </div>
    </form>
  )
}

// ── SpaceBlock ───────────────────────────────────────────────

interface SpaceBlockProps {
  space: SpaceData
  token: string
  onUnauthorized?: () => void
  onEdit: () => void
  onDelete: () => void
}

function SpaceBlock({ space, token, onUnauthorized, onEdit, onDelete }: SpaceBlockProps) {
  const [items, setItems] = useState<SpaceItemData[]>([])
  const [expanded, setExpanded] = useState(true)
  const [showAddItem, setShowAddItem] = useState(false)
  const [editingItem, setEditingItem] = useState<SpaceItemData | null>(null)
  const [error, setError] = useState('')

  const headers = { Authorization: `Bearer ${token}` }

  const fetchItems = useCallback(async () => {
    try {
      const res = await fetch(`${API_URL}/spaces/${space.id}/items`, { headers })
      if (res.status === 401) { onUnauthorized?.(); return }
      if (!res.ok) return
      const data = await res.json()
      setItems(Array.isArray(data) ? data : [])
    } catch (_) {}
  }, [space.id, token])

  useEffect(() => { fetchItems() }, [fetchItems])

  const handleAddItem = async (title: string, content: string) => {
    const res = await fetch(`${API_URL}/spaces/${space.id}/items`, {
      method: 'POST',
      headers: { ...headers, 'Content-Type': 'application/json' },
      body: JSON.stringify({ title, content }),
    })
    if (res.status === 401) { onUnauthorized?.(); return }
    if (!res.ok) throw new Error(await parseError(res))
    setShowAddItem(false)
    await fetchItems()
  }

  const handleUpdateItem = async (item: SpaceItemData, title: string, content: string) => {
    const res = await fetch(`${API_URL}/space-items/${item.id}`, {
      method: 'PUT',
      headers: { ...headers, 'Content-Type': 'application/json' },
      body: JSON.stringify({ title, content }),
    })
    if (res.status === 401) { onUnauthorized?.(); return }
    if (!res.ok) throw new Error(await parseError(res))
    setEditingItem(null)
    await fetchItems()
  }

  const handleDeleteItem = async (item: SpaceItemData) => {
    const label = item.title || item.content.slice(0, 40) || 'this item'
    if (!window.confirm(`Delete "${label}"?`)) return
    setError('')
    try {
      const res = await fetch(`${API_URL}/space-items/${item.id}`, { method: 'DELETE', headers })
      if (res.status === 401) { onUnauthorized?.(); return }
      if (!res.ok) throw new Error(await parseError(res))
      await fetchItems()
    } catch (err) {
      setError((err as Error).message)
    }
  }

  return (
    <div className="space-block">
      <div className="space-block-header">
        <button className="space-block-toggle" onClick={() => setExpanded((v) => !v)}>
          <span className="space-block-chevron">{expanded ? '▾' : '▸'}</span>
          <span className="space-block-name">{space.name}</span>
          {space.space_type && <span className="space-type-pill">{space.space_type}</span>}
          <span className="space-item-count">{items.length}</span>
        </button>
        <div className="space-block-actions">
          <button className="space-action-btn" title="Add item" onClick={() => { setShowAddItem(true); setExpanded(true) }}>+</button>
          <button className="space-action-btn secondary" title="Edit space" onClick={onEdit}>✎</button>
          <button className="space-action-btn secondary" title="Delete space" onClick={onDelete}>✕</button>
        </div>
      </div>

      {error && <div className="error">{error}</div>}

      {expanded && (
        <div className="space-block-body">
          {showAddItem && (
            <SpaceItemForm
              spaceType={space.space_type}
              onSave={handleAddItem}
              onCancel={() => setShowAddItem(false)}
            />
          )}

          {items.length === 0 && !showAddItem ? (
            <p className="space-empty">No items yet.</p>
          ) : (
            items.map((item, idx) => (
              <div className="space-item" key={item.id}>
                {editingItem?.id === item.id ? (
                  <SpaceItemForm
                    spaceType={space.space_type}
                    initial={{ title: item.title ?? '', content: item.content }}
                    onSave={(t, c) => handleUpdateItem(item, t, c)}
                    onCancel={() => setEditingItem(null)}
                  />
                ) : (
                  <>
                    <div className="space-item-header">
                      <span className="space-item-index">{idx + 1}</span>
                      {item.title && <span className="space-item-title">{item.title}</span>}
                      <div className="space-item-actions">
                        <button className="space-action-btn secondary" onClick={() => setEditingItem(item)}>✎</button>
                        <button className="space-action-btn secondary" onClick={() => handleDeleteItem(item)}>✕</button>
                      </div>
                    </div>
                    {item.content && <p className="space-item-content">{item.content}</p>}
                  </>
                )}
              </div>
            ))
          )}
        </div>
      )}
    </div>
  )
}

// ── SpaceManager ─────────────────────────────────────────────

export default function SpaceManager({ folderId, token, onUnauthorized, onCountChange, addTrigger, filterSpaceId }: SpaceManagerProps) {
  const [spaces, setSpaces] = useState<SpaceData[]>([])
  const [showForm, setShowForm] = useState(false)
  const [editingSpace, setEditingSpace] = useState<SpaceData | null>(null)
  const [error, setError] = useState('')
  const [notice, setNotice] = useState('')

  const headers = { Authorization: `Bearer ${token}` }

  const fetchSpaces = useCallback(async () => {
    setError('')
    try {
      const res = await fetch(`${API_URL}/folders/${folderId}/spaces`, { headers })
      if (res.status === 401) { onUnauthorized?.(); return }
      if (!res.ok) throw new Error(await parseError(res))
      const data = await res.json()
      const list: SpaceData[] = Array.isArray(data) ? data : []
      setSpaces(list)
      onCountChange?.(list.length)
    } catch (err) {
      setError((err as Error).message || 'Failed to load spaces')
    }
  }, [folderId, token, onUnauthorized])

  useEffect(() => { fetchSpaces() }, [fetchSpaces])

  useEffect(() => {
    if (addTrigger) {
      setEditingSpace(null)
      setShowForm(true)
      setNotice('')
      setError('')
    }
  }, [addTrigger])

  const handleCreate = async (name: string, spaceType: string, description: string) => {
    const res = await fetch(`${API_URL}/folders/${folderId}/spaces`, {
      method: 'POST',
      headers: { ...headers, 'Content-Type': 'application/json' },
      body: JSON.stringify({ name, space_type: spaceType, description }),
    })
    if (res.status === 401) { onUnauthorized?.(); return }
    if (!res.ok) throw new Error(await parseError(res))
    setShowForm(false)
    setNotice('Space created')
    await fetchSpaces()
  }

  const handleUpdate = async (name: string, spaceType: string, description: string) => {
    if (!editingSpace) return
    const res = await fetch(`${API_URL}/spaces/${editingSpace.id}`, {
      method: 'PUT',
      headers: { ...headers, 'Content-Type': 'application/json' },
      body: JSON.stringify({ name, space_type: spaceType, description }),
    })
    if (res.status === 401) { onUnauthorized?.(); return }
    if (!res.ok) throw new Error(await parseError(res))
    setEditingSpace(null)
    setNotice('Space updated')
    await fetchSpaces()
  }

  const handleDelete = async (space: SpaceData) => {
    if (!window.confirm(`Delete space "${space.name}" and all its items?`)) return
    setError('')
    try {
      const res = await fetch(`${API_URL}/spaces/${space.id}`, { method: 'DELETE', headers })
      if (res.status === 401) { onUnauthorized?.(); return }
      if (!res.ok) throw new Error(await parseError(res))
      setNotice('Space deleted')
      await fetchSpaces()
    } catch (err) {
      setError((err as Error).message || 'Failed to delete space')
    }
  }

  return (
    <div className="space-manager">
      {notice && <div className="notice">{notice}</div>}
      {error && <div className="error">{error}</div>}

      {showForm && (
        <SpaceForm
          onSave={handleCreate}
          onCancel={() => setShowForm(false)}
        />
      )}

      {editingSpace && (
        <SpaceForm
          initial={{ name: editingSpace.name, space_type: editingSpace.space_type ?? '', description: editingSpace.description ?? '' }}
          onSave={handleUpdate}
          onCancel={() => setEditingSpace(null)}
        />
      )}

      <div className="space-list">
        {spaces.length === 0 && !showForm ? (
          <p className="space-empty">No spaces yet.</p>
        ) : (
          spaces.filter((s) => !filterSpaceId || s.id === filterSpaceId).map((space) => (
            <SpaceBlock
              key={space.id}
              space={space}
              token={token}
              onUnauthorized={onUnauthorized}
              onEdit={() => { setEditingSpace(space); setShowForm(false) }}
              onDelete={() => handleDelete(space)}
            />
          ))
        )}
      </div>
    </div>
  )
}
