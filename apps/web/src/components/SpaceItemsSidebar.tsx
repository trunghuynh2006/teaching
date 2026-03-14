import { useCallback, useEffect, useRef, useState } from 'react'
import { API_URL } from '../config'
import ProblemModal from './ProblemModal'
import QuestionModal from './QuestionModal'

interface SpaceInfo {
  id: string
  name: string
  space_type?: string
}

export interface SpaceItemData {
  id: string
  title?: string
  content: string
  position?: number
}

interface SpaceItemsSidebarProps {
  space: SpaceInfo
  token: string
  onUnauthorized?: () => void
  onClose?: () => void
  selectedItemId?: string
  onSelectItem?: (item: SpaceItemData) => void
}

async function parseError(res: Response): Promise<string> {
  try {
    const p = await res.json()
    if (p?.detail) return p.detail
  } catch (_) {}
  return res.statusText || 'Request failed'
}

export default function SpaceItemsSidebar({ space, token, onUnauthorized, selectedItemId, onSelectItem }: SpaceItemsSidebarProps) {
  const [items, setItems] = useState<SpaceItemData[]>([])
  const [showAddForm, setShowAddForm] = useState(false)
  const [showProblemModal, setShowProblemModal] = useState(false)
  const [showQuestionModal, setShowQuestionModal] = useState(false)
  const [addTitle, setAddTitle] = useState('')
  const [addContent, setAddContent] = useState('')
  const [saving, setSaving] = useState(false)
  const [error, setError] = useState('')
  const onSelectItemRef = useRef(onSelectItem)
  onSelectItemRef.current = onSelectItem
  const selectedItemIdRef = useRef(selectedItemId)
  selectedItemIdRef.current = selectedItemId

  const fetchItems = useCallback(async () => {
    try {
      const res = await fetch(`${API_URL}/spaces/${space.id}/items`, {
        headers: { Authorization: `Bearer ${token}` },
      })
      if (res.status === 401) { onUnauthorized?.(); return }
      if (!res.ok) return
      const data = await res.json()
      const list: SpaceItemData[] = Array.isArray(data) ? data : []
      setItems(list)
      // Auto-select first item only if nothing is currently selected
      if (list.length > 0 && !selectedItemIdRef.current) {
        onSelectItemRef.current?.(list[0])
      }
    } catch (_) {}
  }, [space.id, token])

  useEffect(() => { fetchItems() }, [fetchItems])

  const handleAdd = async (e: React.FormEvent) => {
    e.preventDefault()
    setSaving(true)
    setError('')
    try {
      const res = await fetch(`${API_URL}/spaces/${space.id}/items`, {
        method: 'POST',
        headers: { Authorization: `Bearer ${token}`, 'Content-Type': 'application/json' },
        body: JSON.stringify({ title: addTitle.trim(), content: addContent.trim() }),
      })
      if (res.status === 401) { onUnauthorized?.(); return }
      if (!res.ok) throw new Error(await parseError(res))
      const newItem: SpaceItemData = await res.json()
      setAddTitle('')
      setAddContent('')
      setShowAddForm(false)
      await fetchItems()
      onSelectItemRef.current?.(newItem)
    } catch (err) {
      setError((err as Error).message)
    } finally {
      setSaving(false)
    }
  }

  const handleAddClick = () => {
    if (space.space_type === 'Problem') {
      setShowProblemModal(true)
    } else if (space.space_type === 'Question') {
      setShowQuestionModal(true)
    } else {
      setShowAddForm((v) => !v)
    }
  }

  return (
    <nav className="space-items-sidebar">
      <div className="space-items-sidebar-header">
        <span className="space-items-sidebar-name">{space.name}</span>
        <button
          className="folder-sidebar-add-btn always-visible"
          title="Add item"
          onClick={handleAddClick}
        >+</button>
      </div>

      {showAddForm && (
        <form className="space-items-sidebar-add-form" onSubmit={handleAdd}>
          {error && <div className="error" style={{ fontSize: '0.75rem', padding: '0.25rem 0' }}>{error}</div>}
          <input
            autoFocus
            placeholder="Title (optional)"
            value={addTitle}
            onChange={(e) => setAddTitle(e.target.value)}
          />
          <textarea
            placeholder="Content"
            value={addContent}
            onChange={(e) => setAddContent(e.target.value)}
            rows={3}
          />
          <div className="space-items-sidebar-add-actions">
            <button type="submit" disabled={saving}>{saving ? '…' : 'Add'}</button>
            <button type="button" className="secondary" onClick={() => setShowAddForm(false)}>Cancel</button>
          </div>
        </form>
      )}

      <div className="space-items-sidebar-list">
        {items.length === 0 ? (
          <p className="space-items-sidebar-empty">No items</p>
        ) : (
          items.map((item, idx) => (
            <div
              className={`space-items-sidebar-item${item.id === selectedItemId ? ' active' : ''}`}
              key={item.id}
              onClick={() => onSelectItemRef.current?.(item)}
            >
              <span className="space-items-sidebar-index">{idx + 1}</span>
              <span className="space-items-sidebar-label">
                {item.title || item.content.slice(0, 50) || '—'}
              </span>
            </div>
          ))
        )}
      </div>

      {showProblemModal && (
        <ProblemModal
          space={space}
          token={token}
          onUnauthorized={onUnauthorized}
          onSaved={async (item) => {
            setShowProblemModal(false)
            await fetchItems()
            onSelectItemRef.current?.(item)
          }}
          onClose={() => setShowProblemModal(false)}
        />
      )}

      {showQuestionModal && (
        <QuestionModal
          space={space}
          token={token}
          onUnauthorized={onUnauthorized}
          onSaved={async (item) => {
            setShowQuestionModal(false)
            await fetchItems()
            onSelectItemRef.current?.(item)
          }}
          onClose={() => setShowQuestionModal(false)}
        />
      )}
    </nav>
  )
}
