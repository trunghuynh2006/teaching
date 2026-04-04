import { useEffect, useRef, useState } from 'react'
import { API_URL } from '../config'

export interface ConceptItem {
  id: string
  canonical_name: string
  domain?: string
  description?: string
  tags?: string[]
  level?: string
  scope?: string
  prerequisites?: ConceptItem[]
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

const LEVEL_COLORS: Record<string, string> = {
  foundation:   '#2e7d32',
  intermediate: '#1565c0',
  advanced:     '#6a1b9a',
}

export default function ConceptPanel({ concept, token, sourceId, topicId, onClose, onUnlinked }: ConceptPanelProps) {
  const [removing, setRemoving] = useState(false)
  const [error, setError] = useState('')
  const [prerequisites, setPrerequisites] = useState<ConceptItem[]>(concept.prerequisites ?? [])
  const [loadingPrereqs, setLoadingPrereqs] = useState(!concept.prerequisites)
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

  useEffect(() => {
    if (concept.prerequisites) {
      setPrerequisites(concept.prerequisites)
      setLoadingPrereqs(false)
      return
    }
    const load = async () => {
      try {
        const res = await fetch(`${API_URL}/concepts/${concept.id}/prerequisites`, {
          headers: { Authorization: `Bearer ${token}` },
        })
        if (res.ok) setPrerequisites(await res.json())
      } catch (_) {}
      finally { setLoadingPrereqs(false) }
    }
    load()
  }, [concept.id, token])

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

  const levelColor = concept.level ? (LEVEL_COLORS[concept.level] ?? '#555') : undefined

  return (
    <div className="concept-panel-backdrop">
      <div className="concept-panel" ref={panelRef} role="dialog" aria-label="Concept detail">
        <div className="concept-panel-header">
          <h4 className="concept-panel-name">{concept.canonical_name}</h4>
          <button type="button" className="concept-panel-close" onClick={onClose} aria-label="Close">✕</button>
        </div>

        <div className="concept-panel-meta">
          {concept.domain && <span className="concept-panel-domain">{concept.domain}</span>}
          {concept.level && (
            <span className="concept-level-badge" style={{ background: levelColor }}>
              {concept.level}
            </span>
          )}
          {concept.scope && concept.scope !== 'universal' && (
            <span className="concept-scope-badge">{concept.scope}</span>
          )}
        </div>

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

        {/* Prerequisites */}
        <div className="concept-prereq-section">
          <div className="concept-prereq-title">Prerequisites</div>
          {loadingPrereqs ? (
            <p className="concept-prereq-empty">Loading…</p>
          ) : prerequisites.length === 0 ? (
            <p className="concept-prereq-empty">None</p>
          ) : (
            <div className="concept-prereq-list">
              {prerequisites.map((p) => (
                <span
                  key={p.id}
                  className="concept-prereq-chip"
                  style={{ borderColor: p.level ? (LEVEL_COLORS[p.level] ?? '#aaa') : '#aaa' }}
                  title={p.description}
                >
                  {p.canonical_name}
                </span>
              ))}
            </div>
          )}
        </div>

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
