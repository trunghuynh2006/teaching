import { useEffect, useState } from 'react'
import { API_URL } from '../config'
import type { SourceItem } from './KnowledgeManager'

interface GeneratedCard {
  front_text: string
  back_text: string
  bloom_level: string
  tags: string[]
}

interface AnkiGenerateModalProps {
  spaceId: string
  folderId: string
  token: string
  onUnauthorized?: () => void
  onSaved: () => void
  onClose: () => void
}

async function parseError(res: Response): Promise<string> {
  try {
    const p = await res.json()
    if (p?.detail) return p.detail
  } catch (_) {}
  return res.statusText || 'Request failed'
}

export default function AnkiGenerateModal({ spaceId, folderId, token, onUnauthorized, onSaved, onClose }: AnkiGenerateModalProps) {
  const [sources, setSources] = useState<SourceItem[]>([])
  const [loadingSource, setLoadingSource] = useState(true)
  const [selectedSourceId, setSelectedSourceId] = useState('')
  const [generating, setGenerating] = useState(false)
  const [cards, setCards] = useState<GeneratedCard[]>([])
  const [accepted, setAccepted] = useState<boolean[]>([])
  const [saving, setSaving] = useState(false)
  const [error, setError] = useState('')

  const headers = { Authorization: `Bearer ${token}` }

  useEffect(() => {
    const load = async () => {
      try {
        const res = await fetch(`${API_URL}/folders/${folderId}/sources`, { headers })
        if (res.status === 401) { onUnauthorized?.(); return }
        if (!res.ok) return
        const data: SourceItem[] = await res.json()
        // Only show sources that haven't had cards generated yet
        setSources(Array.isArray(data) ? data.filter((s) => !s.anki_generated) : [])
      } finally {
        setLoadingSource(false)
      }
    }
    load()
  }, [folderId, token])

  const handleGenerate = async () => {
    if (!selectedSourceId) return
    setGenerating(true)
    setError('')
    try {
      const res = await fetch(`${API_URL}/spaces/${spaceId}/generate-anki-cards`, {
        method: 'POST',
        headers: { ...headers, 'Content-Type': 'application/json' },
        body: JSON.stringify({ source_id: selectedSourceId }),
      })
      if (res.status === 401) { onUnauthorized?.(); return }
      if (!res.ok) throw new Error(await parseError(res))
      const data = await res.json()
      const generated: GeneratedCard[] = data.cards ?? []
      setCards(generated)
      setAccepted(generated.map(() => true))
    } catch (err) {
      setError((err as Error).message || 'Failed to generate cards')
    } finally {
      setGenerating(false)
    }
  }

  const handleSave = async () => {
    const toSave = cards.filter((_, i) => accepted[i])
    if (toSave.length === 0) { onClose(); return }
    setSaving(true)
    setError('')
    try {
      const results = await Promise.all(toSave.map((c) =>
        fetch(`${API_URL}/spaces/${spaceId}/flash-cards`, {
          method: 'POST',
          headers: { ...headers, 'Content-Type': 'application/json' },
          body: JSON.stringify({ front: c.front_text, back: c.back_text }),
        })
      ))
      const failed = results.find((r) => !r.ok)
      if (failed) {
        const body = await failed.json().catch(() => ({}))
        throw new Error((body as { detail?: string }).detail || `Save failed (${failed.status})`)
      }
      onSaved()
    } catch (err) {
      setError((err as Error).message || 'Failed to save cards')
      setSaving(false)
    }
  }

  const toggle = (i: number) => setAccepted((prev) => prev.map((v, idx) => idx === i ? !v : v))

  return (
    <div className="modal-overlay" onClick={(e) => { if (e.target === e.currentTarget) onClose() }}>
      <div className="modal-box anki-generate-modal">
        <div className="modal-header">
          <span>Generate Anki Cards from Knowledge</span>
          <button className="modal-close" type="button" onClick={onClose}>✕</button>
        </div>
        <div className="modal-body">
          {error && <div className="error">{error}</div>}

          {cards.length === 0 ? (
            <>
              {loadingSource ? (
                <p>Loading sources…</p>
              ) : sources.length === 0 ? (
                <p className="anki-generate-empty">No unused knowledge sources available. All sources have already had cards generated, or no sources exist in this folder.</p>
              ) : (
                <>
                  <label className="modal-field">
                    Select a knowledge source
                    <select
                      value={selectedSourceId}
                      onChange={(e) => setSelectedSourceId(e.target.value)}
                    >
                      <option value="">— choose a source —</option>
                      {sources.map((s) => (
                        <option key={s.id} value={s.id}>
                          {s.title || s.content.slice(0, 60) + (s.content.length > 60 ? '…' : '')}
                        </option>
                      ))}
                    </select>
                  </label>
                  <div className="modal-actions">
                    <button
                      type="button"
                      onClick={handleGenerate}
                      disabled={generating || !selectedSourceId}
                    >
                      {generating ? 'Generating…' : 'Generate Cards'}
                    </button>
                    <button type="button" className="secondary" onClick={onClose}>Cancel</button>
                  </div>
                </>
              )}
            </>
          ) : (
            <>
              <p className="anki-generate-hint">Review the generated cards. Uncheck any you don't want to save.</p>
              <div className="anki-review-list">
                {cards.map((c, i) => (
                  <div key={i} className={`anki-review-card${accepted[i] ? '' : ' rejected'}`}>
                    <label className="anki-review-check">
                      <input type="checkbox" checked={accepted[i]} onChange={() => toggle(i)} />
                      <span className="anki-review-bloom">{c.bloom_level}</span>
                    </label>
                    <div className="anki-review-body">
                      <div className="anki-review-front"><strong>Q:</strong> {c.front_text}</div>
                      <div className="anki-review-back"><strong>A:</strong> {c.back_text}</div>
                    </div>
                  </div>
                ))}
              </div>
              <div className="modal-actions">
                <button type="button" onClick={handleSave} disabled={saving}>
                  {saving ? 'Saving…' : `Save ${accepted.filter(Boolean).length} card${accepted.filter(Boolean).length !== 1 ? 's' : ''}`}
                </button>
                <button type="button" className="secondary" onClick={onClose}>Discard</button>
              </div>
            </>
          )}
        </div>
      </div>
    </div>
  )
}
