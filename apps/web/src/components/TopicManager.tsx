import { useCallback, useEffect, useRef, useState } from 'react'
import { API_URL } from '../config'
import ConceptPanel, { type ConceptItem } from './ConceptPanel'

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

  // concept state per topic
  const [topicConcepts, setTopicConcepts] = useState<Record<string, ConceptItem[]>>({})
  const [selectedConcept, setSelectedConcept] = useState<{ concept: ConceptItem; topicId: string } | null>(null)
  const [addingConceptFor, setAddingConceptFor] = useState<string | null>(null)
  const [conceptSearch, setConceptSearch] = useState('')
  const [searchResults, setSearchResults] = useState<ConceptItem[]>([])
  const [conceptError, setConceptError] = useState('')
  const searchRef = useRef<HTMLDivElement>(null)

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
      // fetch concepts for all topics in parallel
      const entries = await Promise.all(
        items.map(async (t) => {
          const r = await fetch(`${API_URL}/topics/${t.id}/concepts`, { headers })
          const concepts: ConceptItem[] = r.ok ? (await r.json()) ?? [] : []
          return [t.id, concepts] as [string, ConceptItem[]]
        })
      )
      setTopicConcepts(Object.fromEntries(entries))
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

  // ── concept search + link ──────────────────────────────────────────────────

  const openAddConcept = (topicId: string) => {
    setAddingConceptFor(topicId)
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

  const linkConcept = async (topicId: string, concept: ConceptItem) => {
    setConceptError('')
    try {
      const res = await fetch(`${API_URL}/topics/${topicId}/concepts`, {
        method: 'POST',
        headers: { ...headers, 'Content-Type': 'application/json' },
        body: JSON.stringify({ concept_id: concept.id }),
      })
      if (!res.ok) throw new Error('Failed to link concept')
      setTopicConcepts((prev) => ({
        ...prev,
        [topicId]: [...(prev[topicId] ?? []).filter((c) => c.id !== concept.id), concept],
      }))
      closeAddConcept()
    } catch (err) {
      setConceptError((err as Error).message)
    }
  }

  const createAndLink = async (topicId: string) => {
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
      await linkConcept(topicId, newConcept)
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

              {/* concept chips */}
              <div className="concept-chip-row">
                {(topicConcepts[item.id] ?? []).map((c) => (
                  <button
                    key={c.id}
                    type="button"
                    className="concept-chip"
                    onClick={() => setSelectedConcept({ concept: c, topicId: item.id })}
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
          topicId={selectedConcept.topicId}
          onClose={() => setSelectedConcept(null)}
          onUnlinked={() => {
            const { concept, topicId } = selectedConcept
            setTopicConcepts((prev) => ({
              ...prev,
              [topicId]: (prev[topicId] ?? []).filter((c) => c.id !== concept.id),
            }))
          }}
        />
      )}
    </div>
  )
}
