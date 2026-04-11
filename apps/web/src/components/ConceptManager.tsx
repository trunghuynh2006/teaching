import { useCallback, useEffect, useState } from 'react'
import { API_URL } from '../config'
import { ConceptItem } from './ConceptPanel'

interface ConceptManagerProps {
  token: string
  canEdit?: boolean
  onUnauthorized: () => void
}

const LEVELS = ['foundation', 'intermediate', 'advanced']
const SCOPES = ['universal', 'language-specific', 'framework-specific']

const LEVEL_COLOR: Record<string, string> = {
  foundation:   '#2e7d32',
  intermediate: '#1565c0',
  advanced:     '#6a1b9a',
}

interface FormState {
  canonical_name: string
  domain: string
  description: string
  example: string
  analogy: string
  common_mistakes: string
  tags: string        // comma-separated input
  level: string
  scope: string
}

const emptyForm = (): FormState => ({
  canonical_name: '',
  domain: '',
  description: '',
  example: '',
  analogy: '',
  common_mistakes: '',
  tags: '',
  level: 'foundation',
  scope: 'universal',
})

function formFromConcept(c: ConceptItem): FormState {
  return {
    canonical_name: c.canonical_name,
    domain: c.domain ?? '',
    description: c.description ?? '',
    example: c.example ?? '',
    analogy: c.analogy ?? '',
    common_mistakes: c.common_mistakes ?? '',
    tags: (c.tags ?? []).join(', '),
    level: c.level ?? 'foundation',
    scope: c.scope ?? 'universal',
  }
}

export default function ConceptManager({ token, canEdit = false, onUnauthorized }: ConceptManagerProps) {
  const [concepts, setConcepts] = useState<ConceptItem[]>([])
  const [loading, setLoading] = useState(true)
  const [error, setError] = useState('')

  // Filters
  const [filterDomain, setFilterDomain] = useState('')
  const [filterLevel, setFilterLevel] = useState('')
  const [filterSearch, setFilterSearch] = useState('')

  // Modal
  const [showForm, setShowForm] = useState(false)
  const [editId, setEditId] = useState<string | null>(null)
  const [form, setForm] = useState<FormState>(emptyForm())
  const [saving, setSaving] = useState(false)
  const [formError, setFormError] = useState('')

  // Expanded detail
  const [expandedId, setExpandedId] = useState<string | null>(null)

  const authHeaders = useCallback(
    () => ({ Authorization: `Bearer ${token}`, 'Content-Type': 'application/json' }),
    [token],
  )

  const fetchConcepts = useCallback(async () => {
    setLoading(true)
    setError('')
    try {
      const params = new URLSearchParams()
      if (filterDomain) params.set('domain', filterDomain)
      if (filterLevel)  params.set('level', filterLevel)
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
  }, [authHeaders, onUnauthorized, filterDomain, filterLevel])

  useEffect(() => { fetchConcepts() }, [fetchConcepts])

  // All distinct domains from loaded concepts (for filter dropdown)
  const domains = Array.from(new Set(concepts.map(c => c.domain ?? '').filter(Boolean))).sort()

  const filtered = concepts.filter(c => {
    if (!filterSearch) return true
    const q = filterSearch.toLowerCase()
    return c.canonical_name.toLowerCase().includes(q) ||
      (c.description ?? '').toLowerCase().includes(q) ||
      (c.domain ?? '').toLowerCase().includes(q)
  })

  function openCreate() {
    setEditId(null)
    setForm(emptyForm())
    setFormError('')
    setShowForm(true)
  }

  function openEdit(c: ConceptItem) {
    setEditId(c.id)
    setForm(formFromConcept(c))
    setFormError('')
    setShowForm(true)
  }

  async function save() {
    if (!form.canonical_name.trim()) { setFormError('Name is required'); return }
    setSaving(true)
    setFormError('')
    const body = {
      canonical_name:  form.canonical_name.trim(),
      domain:          form.domain.trim(),
      description:     form.description.trim(),
      example:         form.example.trim(),
      analogy:         form.analogy.trim(),
      common_mistakes: form.common_mistakes.trim(),
      tags:            form.tags.split(',').map(t => t.trim()).filter(Boolean),
      level:           form.level,
      scope:           form.scope,
    }
    try {
      const url  = editId ? `${API_URL}/concepts/${editId}` : `${API_URL}/concepts`
      const method = editId ? 'PUT' : 'POST'
      const res = await fetch(url, { method, headers: authHeaders(), body: JSON.stringify(body) })
      if (res.status === 401) { onUnauthorized(); return }
      if (!res.ok) {
        const data = await res.json().catch(() => ({}))
        setFormError(data.detail ?? 'Failed to save')
        return
      }
      setShowForm(false)
      fetchConcepts()
    } finally {
      setSaving(false)
    }
  }

  async function deleteConcept(c: ConceptItem) {
    if (!confirm(`Delete "${c.canonical_name}"?`)) return
    const res = await fetch(`${API_URL}/concepts/${c.id}`, { method: 'DELETE', headers: authHeaders() })
    if (res.status === 401) { onUnauthorized(); return }
    fetchConcepts()
  }

  function field(label: string, key: keyof FormState, type: 'input' | 'textarea' = 'input', placeholder = '') {
    return (
      <div className="modal-field">
        <label>{label}</label>
        {type === 'textarea' ? (
          <textarea
            className="modal-textarea"
            rows={3}
            value={form[key]}
            placeholder={placeholder}
            onChange={e => setForm(f => ({ ...f, [key]: e.target.value }))}
          />
        ) : (
          <input
            type="text"
            value={form[key]}
            placeholder={placeholder}
            onChange={e => setForm(f => ({ ...f, [key]: e.target.value }))}
          />
        )}
      </div>
    )
  }

  return (
    <div className="concept-manager">
      {/* ── Header ── */}
      <div className="concept-manager-header">
        <h2>Concepts</h2>
        {canEdit && <button className="btn-primary" onClick={openCreate}>+ New Concept</button>}
      </div>

      {/* ── Filters ── */}
      <div className="concept-manager-filters">
        <input
          type="text"
          placeholder="Search name or description…"
          value={filterSearch}
          onChange={e => setFilterSearch(e.target.value)}
          className="concept-filter-search"
        />
        <select value={filterDomain} onChange={e => setFilterDomain(e.target.value)} className="concept-filter-select">
          <option value="">All domains</option>
          {domains.map(d => <option key={d} value={d}>{d}</option>)}
        </select>
        <select value={filterLevel} onChange={e => setFilterLevel(e.target.value)} className="concept-filter-select">
          <option value="">All levels</option>
          {LEVELS.map(l => <option key={l} value={l}>{l}</option>)}
        </select>
        <span className="concept-manager-count">{filtered.length} concepts</span>
      </div>

      {error && <div className="error-msg">{error}</div>}

      {/* ── List ── */}
      {loading ? (
        <div className="loading">Loading…</div>
      ) : filtered.length === 0 ? (
        <div className="empty-state">No concepts found.</div>
      ) : (
        <div className="concept-manager-list">
          {filtered.map(c => {
            const expanded = expandedId === c.id
            return (
              <div key={c.id} className={`concept-manager-row ${expanded ? 'concept-manager-row--open' : ''}`}>
                <div className="concept-manager-row-main" onClick={() => setExpandedId(expanded ? null : c.id)}>
                  <div className="concept-manager-row-left">
                    <span className="concept-manager-chevron">{expanded ? '▾' : '▸'}</span>
                    <span className="concept-manager-name">{c.canonical_name}</span>
                    {c.domain && <span className="concept-manager-domain">{c.domain}</span>}
                  </div>
                  <div className="concept-manager-row-right">
                    {c.level && (
                      <span className="concept-level-badge" style={{ background: LEVEL_COLOR[c.level] ?? '#888' }}>
                        {c.level}
                      </span>
                    )}
                    {c.scope && c.scope !== 'universal' && (
                      <span className="concept-scope-badge">{c.scope}</span>
                    )}
                    {canEdit && <button className="btn-sm btn-secondary" onClick={e => { e.stopPropagation(); openEdit(c) }}>Edit</button>}
                    {canEdit && <button className="btn-sm btn-danger"    onClick={e => { e.stopPropagation(); deleteConcept(c) }}>Delete</button>}
                  </div>
                </div>

                {expanded && (
                  <div className="concept-manager-detail">
                    {c.description && (
                      <div className="concept-panel-block">
                        <span className="concept-panel-block-label">Description</span>
                        <p className="concept-panel-block-text">{c.description}</p>
                      </div>
                    )}
                    {c.example && (
                      <div className="concept-panel-block">
                        <span className="concept-panel-block-label">Example</span>
                        <p className="concept-panel-block-text">{c.example}</p>
                      </div>
                    )}
                    {c.analogy && (
                      <div className="concept-panel-block">
                        <span className="concept-panel-block-label">Analogy</span>
                        <p className="concept-panel-block-text">{c.analogy}</p>
                      </div>
                    )}
                    {c.common_mistakes && (
                      <div className="concept-panel-block concept-panel-block--warning">
                        <span className="concept-panel-block-label">Common Mistakes</span>
                        <p className="concept-panel-block-text">{c.common_mistakes}</p>
                      </div>
                    )}
                    {c.tags && c.tags.length > 0 && (
                      <div className="concept-chip-row" style={{ marginTop: 8 }}>
                        {c.tags.map(t => <span key={t} className="concept-tag">{t}</span>)}
                      </div>
                    )}
                  </div>
                )}
              </div>
            )
          })}
        </div>
      )}

      {/* ── Create / Edit modal ── */}
      {showForm && (
        <div className="modal-overlay" onClick={() => setShowForm(false)}>
          <div className="modal-box" onClick={e => e.stopPropagation()}>
            <div className="modal-header">
              <span>{editId ? 'Edit Concept' : 'New Concept'}</span>
            </div>
            <div className="modal-body">
              {field('Name *', 'canonical_name', 'input', 'e.g. Recursion')}
              {field('Domain', 'domain', 'input', 'e.g. computer science')}

              <div className="concept-form-row">
                <div className="modal-field">
                  <label>Level</label>
                  <select value={form.level} onChange={e => setForm(f => ({ ...f, level: e.target.value }))} className="modal-select">
                    {LEVELS.map(l => <option key={l} value={l}>{l}</option>)}
                  </select>
                </div>
                <div className="modal-field">
                  <label>Scope</label>
                  <select value={form.scope} onChange={e => setForm(f => ({ ...f, scope: e.target.value }))} className="modal-select">
                    {SCOPES.map(s => <option key={s} value={s}>{s}</option>)}
                  </select>
                </div>
              </div>

              {field('Description', 'description', 'textarea', 'Clear 1-2 sentence explanation')}
              {field('Example', 'example', 'textarea', 'Concrete usage example')}
              {field('Analogy', 'analogy', 'textarea', 'Everyday comparison')}
              {field('Common Mistakes', 'common_mistakes', 'textarea', 'What learners typically get wrong')}
              {field('Tags', 'tags', 'input', 'Comma-separated: basics, OOP, recursion')}

              {formError && <div className="error-msg">{formError}</div>}
              <div className="modal-actions">
                <button className="btn-secondary" onClick={() => setShowForm(false)}>Cancel</button>
                <button className="btn-primary" onClick={save} disabled={saving}>
                  {saving ? 'Saving…' : 'Save'}
                </button>
              </div>
            </div>
          </div>
        </div>
      )}
    </div>
  )
}
