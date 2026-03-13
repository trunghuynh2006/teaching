import { useCallback, useEffect, useState } from 'react'
import { API_URL } from '../config'

interface SpaceInfo {
  id: string
  name: string
  space_type?: string
}

interface SpaceItemData {
  id: string
  title?: string
  content: string
  position?: number
}

interface SpaceItemsSidebarProps {
  space: SpaceInfo
  token: string
  onUnauthorized?: () => void
  onClose: () => void
}

export default function SpaceItemsSidebar({ space, token, onUnauthorized, onClose }: SpaceItemsSidebarProps) {
  const [items, setItems] = useState<SpaceItemData[]>([])

  const fetchItems = useCallback(async () => {
    try {
      const res = await fetch(`${API_URL}/spaces/${space.id}/items`, {
        headers: { Authorization: `Bearer ${token}` },
      })
      if (res.status === 401) { onUnauthorized?.(); return }
      if (!res.ok) return
      const data = await res.json()
      setItems(Array.isArray(data) ? data : [])
    } catch (_) {}
  }, [space.id, token])

  useEffect(() => { fetchItems() }, [fetchItems])

  return (
    <nav className="space-items-sidebar">
      <div className="space-items-sidebar-header">
        <span className="space-items-sidebar-name">{space.name}</span>
        {space.space_type && <span className="space-type-pill">{space.space_type}</span>}
        <button className="space-items-sidebar-close" title="Close" onClick={onClose}>✕</button>
      </div>

      <div className="space-items-sidebar-list">
        {items.length === 0 ? (
          <p className="space-items-sidebar-empty">No items</p>
        ) : (
          items.map((item, idx) => (
            <div className="space-items-sidebar-item" key={item.id}>
              <span className="space-items-sidebar-index">{idx + 1}</span>
              <span className="space-items-sidebar-label">
                {item.title || item.content.slice(0, 50) || '—'}
              </span>
            </div>
          ))
        )}
      </div>
    </nav>
  )
}
