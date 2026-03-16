import { useCallback, useEffect, useState } from 'react'
import { API_URL } from '../config'
import ProblemModal from './ProblemModal'

interface SpaceInfo {
  id: string
  name: string
  space_type?: string
}

interface SidebarItem {
  id: string
  label: string
}

interface SpaceItemsSidebarProps {
  space: SpaceInfo
  token: string
  onUnauthorized?: () => void
  onAdded?: () => void
  selectedItemId?: string | null
  onSelectItem?: (id: string) => void
  refreshKey?: number
}

export default function SpaceItemsSidebar({ space, token, onUnauthorized, onAdded, selectedItemId, onSelectItem, refreshKey }: SpaceItemsSidebarProps) {
  const [showProblemModal, setShowProblemModal] = useState(false)
  const [items, setItems] = useState<SidebarItem[]>([])

  const fetchItems = useCallback(async () => {
    try {
      let endpoint = ''
      if (space.space_type === 'Problem') endpoint = 'problems'
      else return
      const res = await fetch(`${API_URL}/spaces/${space.id}/${endpoint}`, {
        headers: { Authorization: `Bearer ${token}` },
      })
      if (res.status === 401) { onUnauthorized?.(); return }
      if (!res.ok) return
      const data = await res.json()
      if (Array.isArray(data)) {
        setItems(data.map((item: { id: string; question?: string; name?: string }) => ({
          id: item.id,
          label: item.question || item.name || item.id,
        })))
      }
    } catch (_) {}
  }, [space.id, space.space_type, token])

  useEffect(() => { fetchItems() }, [fetchItems, refreshKey])

  const handleAddClick = () => {
    if (space.space_type === 'Problem') setShowProblemModal(true)
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

      <div className="space-items-list">
        {items.map((item) => (
          <a
            key={item.id}
            className={`space-items-list-item${selectedItemId === item.id ? ' active' : ''}`}
            onClick={() => onSelectItem?.(item.id)}
            role="button"
          >
            {item.label}
          </a>
        ))}
        {items.length === 0 && (
          <span className="space-items-empty">No items yet</span>
        )}
      </div>

      {showProblemModal && (
        <ProblemModal
          space={space}
          token={token}
          onUnauthorized={onUnauthorized}
          onSaved={() => { setShowProblemModal(false); onAdded?.() }}
          onClose={() => setShowProblemModal(false)}
        />
      )}
    </nav>
  )
}
