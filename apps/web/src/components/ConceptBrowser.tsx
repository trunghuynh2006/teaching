import { useCallback, useEffect, useState } from 'react'
import { API_URL } from '../config'
import ConceptPanel, { ConceptItem } from './ConceptPanel'

interface ConceptBrowserProps {
  token: string
  onUnauthorized: () => void
}

const LEVELS = ['foundation', 'intermediate', 'advanced'] as const

const LEVEL_COLOR: Record<string, string> = {
  foundation:   '#2e7d32',
  intermediate: '#1565c0',
  advanced:     '#6a1b9a',
}

const LEVEL_LABEL: Record<string, string> = {
  foundation:   'Foundation',
  intermediate: 'Intermediate',
  advanced:     'Advanced',
}

export default function ConceptBrowser({ token, onUnauthorized }: ConceptBrowserProps) {
  const [concepts, setConcepts] = useState<ConceptItem[]>([])
  const [loading, setLoading] = useState(true)
  const [error, setError] = useState('')
  const [selectedDomain, setSelectedDomain] = useState('')
  const [search, setSearch] = useState('')
  const [selected, setSelected] = useState<ConceptItem | null>(null)

  const authHeaders = useCallback(
    () => ({ Authorization: `Bearer ${token}` }),
    [token],
  )

  const fetchConcepts = useCallback(async () => {
    setLoading(true)
    setError('')
    try {
      const params = new URLSearchParams()
      if (selectedDomain) params.set('domain', selectedDomain)
      const res = await fetch(`${API_URL}/concepts?${params}`, { headers: authHeaders() })
      if (res.status === 401) { onUnauthorized(); return }
      if (!res.ok) throw new Error('Failed to load concepts')
      const data = await res.json()
      setConcepts(Array.isArray(data) ? data : (data.concepts ?? []))
    } catch (e: unknown) {
      setError(e instanceof Error ? e.message : 'Unknown error')
    } finally {
      setLoading(false)
    }
  }, [authHeaders, onUnauthorized, selectedDomain])

  useEffect(() => { fetchConcepts() }, [fetchConcepts])

  const domains = Array.from(new Set(concepts.map(c => c.domain ?? '').filter(Boolean))).sort()

  const filtered = concepts.filter(c => {
    if (!search) return true
    const q = search.toLowerCase()
    return c.canonical_name.toLowerCase().includes(q) ||
      (c.description ?? '').toLowerCase().includes(q)
  })

  const byLevel = LEVELS.map(level => ({
    level,
    items: filtered.filter(c => c.level === level),
  })).filter(g => g.items.length > 0)

  // Ungrouped concepts (no level or unexpected level)
  const ungrouped = filtered.filter(c => !c.level || !LEVELS.includes(c.level as typeof LEVELS[number]))

  return (
    <div className="concept-browser">
      {/* ── Header ── */}
      <div className="concept-browser-header">
        <div>
          <h2>Concept Library</h2>
          <p className="concept-browser-subtitle">
            Browse concepts by domain and level to build your understanding.
          </p>
        </div>
      </div>

      {/* ── Filters ── */}
      <div className="concept-manager-filters">
        <input
          type="text"
          placeholder="Search concepts…"
          value={search}
          onChange={e => setSearch(e.target.value)}
          className="concept-filter-search"
        />
        <select
          value={selectedDomain}
          onChange={e => setSelectedDomain(e.target.value)}
          className="concept-filter-select"
        >
          <option value="">All domains</option>
          {domains.map(d => <option key={d} value={d}>{d}</option>)}
        </select>
        <span className="concept-manager-count">{filtered.length} concepts</span>
      </div>

      {error && <div className="error-msg">{error}</div>}

      {loading ? (
        <div className="loading">Loading…</div>
      ) : filtered.length === 0 ? (
        <div className="empty-state">No concepts found.</div>
      ) : (
        <div className="concept-browser-body">
          {byLevel.map(({ level, items }) => (
            <section key={level} className="concept-browser-group">
              <div
                className="concept-browser-group-header"
                style={{ borderLeftColor: LEVEL_COLOR[level] }}
              >
                <span
                  className="concept-level-badge"
                  style={{ background: LEVEL_COLOR[level] }}
                >
                  {LEVEL_LABEL[level]}
                </span>
                <span className="concept-browser-group-count">{items.length} concepts</span>
              </div>

              <div className="concept-browser-grid">
                {items.map(c => (
                  <button
                    key={c.id}
                    className="concept-browser-card"
                    onClick={() => setSelected(c)}
                    type="button"
                  >
                    <div className="concept-browser-card-name">{c.canonical_name}</div>
                    {c.domain && (
                      <div className="concept-browser-card-domain">{c.domain}</div>
                    )}
                    {c.description && (
                      <div className="concept-browser-card-desc">{c.description}</div>
                    )}
                    {c.tags && c.tags.length > 0 && (
                      <div className="concept-chip-row" style={{ marginTop: 'auto', paddingTop: 8 }}>
                        {c.tags.slice(0, 3).map(t => (
                          <span key={t} className="concept-tag">{t}</span>
                        ))}
                        {c.tags.length > 3 && (
                          <span className="concept-tag">+{c.tags.length - 3}</span>
                        )}
                      </div>
                    )}
                  </button>
                ))}
              </div>
            </section>
          ))}

          {ungrouped.length > 0 && (
            <section className="concept-browser-group">
              <div className="concept-browser-group-header" style={{ borderLeftColor: '#888' }}>
                <span className="concept-scope-badge">Other</span>
                <span className="concept-browser-group-count">{ungrouped.length} concepts</span>
              </div>
              <div className="concept-browser-grid">
                {ungrouped.map(c => (
                  <button
                    key={c.id}
                    className="concept-browser-card"
                    onClick={() => setSelected(c)}
                    type="button"
                  >
                    <div className="concept-browser-card-name">{c.canonical_name}</div>
                    {c.description && (
                      <div className="concept-browser-card-desc">{c.description}</div>
                    )}
                  </button>
                ))}
              </div>
            </section>
          )}
        </div>
      )}

      {selected && (
        <ConceptPanel
          concept={selected}
          token={token}
          onClose={() => setSelected(null)}
        />
      )}
    </div>
  )
}
