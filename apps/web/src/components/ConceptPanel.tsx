import { useEffect, useRef, useState } from 'react'
import { API_URL } from '../config'

export interface ConceptItem {
  id: string
  canonical_name: string
  domain?: string
  description?: string
  tags?: string[]
}

interface ConceptPanelProps {
  concept: ConceptItem
  token: string
  /** If set, shows a Remove button that unlinks from this source */
  sourceId?: string
  /** If set, shows a Remove button that unlinks from this topic */
  topicId?: string
  onClose: () => void
  onUnlinked?: () => void
}

export default function ConceptPanel({ concept, token, sourceId, topicId, onClose, onUnlinked }: ConceptPanelProps) {
  const [removing, setRemoving] = useState(false)
  const [error, setError] = useState('')
  const panelRef = useRef<HTMLDivElement>(null)

  useEffect(() => {
    const handleKey = (e: KeyboardEvent) => { if (e.key === 'Escape') onClose() }
    document.addEventListener('keydown', handleKey)
    return () => document.removeEventListener('keydown', handleKey)
  }, [onClose])

  useEffect(() => {
    const handleClick = (e: MouseEvent) => {
      if (panelRef.current && !panelRef.current.contains(e.target as Node)) onClose()
    }
    document.addEventListener('mousedown', handleClick)
    return () => document.removeEventListener('mousedown', handleClick)
  }, [onClose])

  const handleUnlink = async () => {
    setError('')
    setRemoving(true)
    const url = sourceId
      ? `${API_URL}/sources/${sourceId}/concepts/${concept.id}`
      : `${API_URL}/topics/${topicId}/concepts/${concept.id}`
    try {
      const res = await fetch(url, {
        method: 'DELETE',
        headers: { Authorization: `Bearer ${token}` },
      })
      if (!res.ok) throw new Error('Failed to remove')
      onUnlinked?.()
      onClose()
    } catch (err) {
      setError((err as Error).message)
    } finally {
      setRemoving(false)
    }
  }

  return (
    <div className="concept-panel-backdrop">
      <div className="concept-panel" ref={panelRef} role="dialog" aria-label="Concept detail">
        <div className="concept-panel-header">
          <h4 className="concept-panel-name">{concept.canonical_name}</h4>
          <button type="button" className="concept-panel-close" onClick={onClose} aria-label="Close">✕</button>
        </div>

        {concept.domain && (
          <p className="concept-panel-domain">{concept.domain}</p>
        )}

        {concept.description && (
          <p className="concept-panel-desc">{concept.description}</p>
        )}

        {concept.tags && concept.tags.length > 0 && (
          <div className="concept-chip-row">
            {concept.tags.map((tag) => (
              <span key={tag} className="concept-tag">{tag}</span>
            ))}
          </div>
        )}

        {error && <p className="error" style={{ marginTop: '0.5rem' }}>{error}</p>}

        {(sourceId || topicId) && (
          <div style={{ marginTop: '0.75rem' }}>
            <button
              type="button"
              className="secondary"
              onClick={handleUnlink}
              disabled={removing}
            >
              {removing ? 'Removing…' : 'Remove from here'}
            </button>
          </div>
        )}
      </div>
    </div>
  )
}
