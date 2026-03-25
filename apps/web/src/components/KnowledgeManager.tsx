import { useCallback, useEffect, useRef, useState } from 'react'
import { API_URL } from '../config'
import ConceptPanel, { type ConceptItem } from './ConceptPanel'

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
  const [showModal, setShowModal] = useState(false)
  const [loading, setLoading] = useState(false)
  const [saving, setSaving] = useState(false)
  const [error, setError] = useState('')
  const [notice, setNotice] = useState('')

  // concept state per source
  const [sourceConcepts, setSourceConcepts] = useState<Record<string, ConceptItem[]>>({})
  const [selectedConcept, setSelectedConcept] = useState<{ concept: ConceptItem; sourceId: string } | null>(null)
  const [addingConceptFor, setAddingConceptFor] = useState<string | null>(null)
  const [conceptSearch, setConceptSearch] = useState('')
  const [searchResults, setSearchResults] = useState<ConceptItem[]>([])
  const [conceptError, setConceptError] = useState('')
  const searchRef = useRef<HTMLDivElement>(null)

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
      // fetch concepts for all sources in parallel
      const entries = await Promise.all(
        items.map(async (s) => {
          const r = await fetch(`${API_URL}/sources/${s.id}/concepts`, { headers })
          const concepts: ConceptItem[] = r.ok ? (await r.json()) ?? [] : []
          return [s.id, concepts] as [string, ConceptItem[]]
        })
      )
      setSourceConcepts(Object.fromEntries(entries))
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
      setShowModal(true)
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
    setShowModal(false)
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

  // ── concept search + link ──────────────────────────────────────────────────

  const openAddConcept = (sourceId: string) => {
    setAddingConceptFor(sourceId)
    setConceptSearch('')
    setSearchResults([])
    setConceptError('')
  }

  const closeAddConcept = () => {
    setAddingConceptFor(null)
    setConceptSearch('')
    setSearchResults([])
    setConceptError('')
  }

  useEffect(() => {
    const handle = (e: MouseEvent) => {
      if (searchRef.current && !searchRef.current.contains(e.target as Node)) closeAddConcept()
    }
    if (addingConceptFor) document.addEventListener('mousedown', handle)
    return () => document.removeEventListener('mousedown', handle)
  }, [addingConceptFor])

  const searchConcepts = async (q: string) => {
    setConceptSearch(q)
    if (q.trim().length < 1) { setSearchResults([]); return }
    try {
      const res = await fetch(`${API_URL}/concepts`, { headers })
      if (!res.ok) return
      const all: ConceptItem[] = (await res.json()) ?? []
      const lower = q.toLowerCase()
      setSearchResults(all.filter((c) => c.canonical_name.toLowerCase().includes(lower)).slice(0, 8))
    } catch (_) {}
  }

  const linkConcept = async (sourceId: string, concept: ConceptItem) => {
    setConceptError('')
    try {
      const res = await fetch(`${API_URL}/sources/${sourceId}/concepts`, {
        method: 'POST',
        headers: { ...headers, 'Content-Type': 'application/json' },
        body: JSON.stringify({ concept_id: concept.id }),
      })
      if (!res.ok) throw new Error('Failed to link concept')
      setSourceConcepts((prev) => ({
        ...prev,
        [sourceId]: [...(prev[sourceId] ?? []).filter((c) => c.id !== concept.id), concept],
      }))
      closeAddConcept()
    } catch (err) {
      setConceptError((err as Error).message)
    }
  }

  const createAndLink = async (sourceId: string) => {
    const name = conceptSearch.trim()
    if (!name) return
    setConceptError('')
    try {
      const createRes = await fetch(`${API_URL}/concepts`, {
        method: 'POST',
        headers: { ...headers, 'Content-Type': 'application/json' },
        body: JSON.stringify({ canonical_name: name }),
      })
      if (!createRes.ok) throw new Error('Failed to create concept')
      const newConcept: ConceptItem = await createRes.json()
      await linkConcept(sourceId, newConcept)
    } catch (err) {
      setConceptError((err as Error).message)
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

      {showModal && (
        <div className="modal-overlay" onClick={(e) => { if (e.target === e.currentTarget) cancelForm() }}>
          <div className="modal-box">
            <div className="modal-header">
              <span>Add Knowledge</span>
              <button className="modal-close" type="button" onClick={cancelForm}>✕</button>
            </div>
            <div className="modal-body">
              {error && <div className="error">{error}</div>}
              <form onSubmit={handleSubmit}>
                <label className="modal-field">
                  Title (optional)
                  <input
                    autoFocus
                    value={form.title}
                    onChange={(e) => setForm((prev) => ({ ...prev, title: e.target.value }))}
                    placeholder="e.g. Definition of velocity"
                  />
                </label>
                <label className="modal-field">
                  Content
                  <textarea
                    className="modal-textarea"
                    value={form.content}
                    onChange={(e) => setForm((prev) => ({ ...prev, content: e.target.value }))}
                    placeholder="Write the source content here…"
                    required
                  />
                </label>
                <div className="modal-actions">
                  <button type="submit" disabled={saving}>
                    {saving ? 'Saving…' : 'Create'}
                  </button>
                  <button type="button" className="secondary" onClick={cancelForm}>Cancel</button>
                </div>
              </form>
            </div>
          </div>
        </div>
      )}

      <div className="knowledge-list">
        {sources.length === 0 && !loading && !showForm ? (
          <p className="knowledge-empty">No entries yet.</p>
        ) : (
          sources.map((item) => (
            <article className="knowledge-item" key={item.id}>
              {item.title && <h5 className="knowledge-title">{item.title}</h5>}
              <p className="knowledge-content">{item.content}</p>

              {/* concept chips */}
              <div className="concept-chip-row">
                {(sourceConcepts[item.id] ?? []).map((c) => (
                  <button
                    key={c.id}
                    type="button"
                    className="concept-chip"
                    onClick={() => setSelectedConcept({ concept: c, sourceId: item.id })}
                  >
                    {c.canonical_name}
                    {c.domain && <span className="concept-chip-domain">{c.domain}</span>}
                  </button>
                ))}

                {addingConceptFor === item.id ? (
                  <div className="concept-add-popover" ref={searchRef}>
                    <input
                      autoFocus
                      className="concept-search-input"
                      value={conceptSearch}
                      onChange={(e) => searchConcepts(e.target.value)}
                      placeholder="Search or create concept…"
                      onKeyDown={(e) => { if (e.key === 'Escape') closeAddConcept() }}
                    />
                    {conceptError && <p className="error" style={{ margin: '0.25rem 0 0' }}>{conceptError}</p>}
                    <ul className="concept-search-results">
                      {searchResults.map((c) => (
                        <li key={c.id}>
                          <button type="button" onClick={() => linkConcept(item.id, c)}>
                            {c.canonical_name}
                            {c.domain && <span className="concept-chip-domain">{c.domain}</span>}
                          </button>
                        </li>
                      ))}
                      {conceptSearch.trim() && (
                        <li className="concept-create-option">
                          <button type="button" onClick={() => createAndLink(item.id)}>
                            + Create "{conceptSearch.trim()}"
                          </button>
                        </li>
                      )}
                    </ul>
                  </div>
                ) : (
                  <button
                    type="button"
                    className="concept-chip concept-chip-add"
                    onClick={() => openAddConcept(item.id)}
                    title="Add concept"
                  >
                    +
                  </button>
                )}
              </div>

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

      {selectedConcept && (
        <ConceptPanel
          concept={selectedConcept.concept}
          token={token}
          sourceId={selectedConcept.sourceId}
          onClose={() => setSelectedConcept(null)}
          onUnlinked={() => {
            const { concept, sourceId } = selectedConcept
            setSourceConcepts((prev) => ({
              ...prev,
              [sourceId]: (prev[sourceId] ?? []).filter((c) => c.id !== concept.id),
            }))
          }}
        />
      )}
    </div>
  )
}
