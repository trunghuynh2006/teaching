import { useCallback, useEffect, useState } from 'react'
import { API_URL } from '../config'
import ConceptPanel, { type ConceptItem } from './ConceptPanel'

export interface SourceItem {
  id: string
  folder_id: string
  title?: string
  content: string
  anki_generated?: boolean
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
  urlInput: string
}

const DEFAULT_FORM: FormState = { title: '', content: '', urlInput: '' }

async function parseError(response: Response): Promise<string> {
  try {
    const payload = await response.json()
    if (payload?.detail) return payload.detail
  } catch (_) {}
  return response.statusText || 'Request failed'
}

export default function KnowledgeManager({ folderId, token, onUnauthorized, onCountChange, addTrigger }: KnowledgeManagerProps) {
  const [sources, setSources] = useState<SourceItem[]>([])
  const [editingItem, setEditingItem] = useState<SourceItem | null>(null)
  const [form, setForm] = useState<FormState>(DEFAULT_FORM)
  const [showForm, setShowForm] = useState(false)
  const [showModal, setShowModal] = useState(false)
  const [loading, setLoading] = useState(false)
  const [saving, setSaving] = useState(false)
  const [fetching, setFetching] = useState(false)
  const [error, setError] = useState('')
  const [notice, setNotice] = useState('')

  const [sourceConcepts, setSourceConcepts] = useState<Record<string, ConceptItem[]>>({})
  const [selectedConcept, setSelectedConcept] = useState<{ concept: ConceptItem; sourceId: string } | null>(null)
  const [generatingFor, setGeneratingFor] = useState<string | null>(null)
  const [conceptError, setConceptError] = useState<Record<string, string>>({})

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
    setForm({ title: item.title ?? '', content: item.content, urlInput: '' })
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

  const fetchFromURL = async () => {
    const rawURL = form.urlInput.trim()
    if (!rawURL) return
    setFetching(true)
    setError('')
    try {
      const res = await fetch(`${API_URL}/sources/fetch-url`, {
        method: 'POST',
        headers: { ...headers, 'Content-Type': 'application/json' },
        body: JSON.stringify({ url: rawURL }),
      })
      if (res.status === 401) { onUnauthorized?.(); return }
      if (!res.ok) throw new Error(await parseError(res))
      const data = await res.json()
      setForm((prev) => ({
        ...prev,
        title: prev.title || data.title || '',
        content: data.content || '',
      }))
    } catch (err) {
      setError((err as Error).message || 'Failed to fetch URL')
    } finally {
      setFetching(false)
    }
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

  const generateConcepts = async (sourceId: string) => {
    setGeneratingFor(sourceId)
    setConceptError((prev) => ({ ...prev, [sourceId]: '' }))
    try {
      const res = await fetch(`${API_URL}/sources/${sourceId}/generate-concepts`, {
        method: 'POST',
        headers,
      })
      if (res.status === 401) { onUnauthorized?.(); return }
      if (!res.ok) throw new Error(await parseError(res))
      const concepts: ConceptItem[] = (await res.json()) ?? []
      setSourceConcepts((prev) => ({ ...prev, [sourceId]: concepts }))
    } catch (err) {
      setConceptError((prev) => ({ ...prev, [sourceId]: (err as Error).message || 'Failed to generate concepts' }))
    } finally {
      setGeneratingFor(null)
    }
  }

  const urlField = (
    <>
      <label>
        URL (optional — fetch content from a public page)
        <div className="url-fetch-row">
          <input
            value={form.urlInput}
            onChange={(e) => setForm((prev) => ({ ...prev, urlInput: e.target.value }))}
            placeholder="https://example.com/article"
            type="url"
          />
          <button type="button" className="secondary" onClick={fetchFromURL} disabled={fetching || !form.urlInput.trim()}>
            {fetching ? 'Fetching…' : 'Fetch'}
          </button>
        </div>
      </label>
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
    </>
  )

  return (
    <div className="knowledge-manager">
      {notice && <div className="notice">{notice}</div>}
      {error && <div className="error">{error}</div>}

      {showForm && (
        <form className="skill-form" onSubmit={handleSubmit}>
          {urlField}
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
                  URL (optional — fetch content from a public page)
                  <div className="url-fetch-row">
                    <input
                      value={form.urlInput}
                      onChange={(e) => setForm((prev) => ({ ...prev, urlInput: e.target.value }))}
                      placeholder="https://example.com/article"
                      type="url"
                    />
                    <button type="button" className="secondary" onClick={fetchFromURL} disabled={fetching || !form.urlInput.trim()}>
                      {fetching ? 'Fetching…' : 'Fetch'}
                    </button>
                  </div>
                </label>
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
          sources.map((item) => {
            const concepts = sourceConcepts[item.id] ?? []
            const hasConceptsGenerated = concepts.length > 0
            const isGenerating = generatingFor === item.id
            return (
              <article className="knowledge-item" key={item.id}>
                <div className="knowledge-card-header">
                  <div className="knowledge-card-text">
                    <h5 className="knowledge-title">
                      {item.title || item.content.slice(0, 60) + (item.content.length > 60 ? '…' : '')}
                    </h5>
                    {item.title && (
                      <p className="knowledge-excerpt">
                        {item.content.slice(0, 120)}{item.content.length > 120 ? '…' : ''}
                      </p>
                    )}
                  </div>
                  <div className="knowledge-card-actions">
                    <button type="button" className="secondary btn-sm" onClick={() => openEditForm(item)}>Edit</button>
                    <button type="button" className="secondary btn-sm" onClick={() => handleDelete(item)}>Delete</button>
                  </div>
                </div>

                <div className="concept-chip-row">
                  {concepts.map((c) => (
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
                  <button
                    type="button"
                    className="btn-generate-concepts"
                    onClick={() => generateConcepts(item.id)}
                    disabled={hasConceptsGenerated || isGenerating}
                    title={hasConceptsGenerated ? 'Concepts already generated' : 'Generate concepts with AI'}
                  >
                    {isGenerating ? 'Generating…' : 'Generate concepts'}
                  </button>
                  {conceptError[item.id] && (
                    <span className="concept-gen-error">{conceptError[item.id]}</span>
                  )}
                </div>
              </article>
            )
          })
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
