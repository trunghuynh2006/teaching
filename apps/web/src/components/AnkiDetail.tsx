import { useCallback, useEffect, useState } from 'react'
import { API_URL } from '../config'

interface FlashCard {
  id: string
  front: string
  back: string
  due_at?: string
  interval_days?: number
  ease_factor?: number
  review_count?: number
}

interface TopicItem {
  id: string
  name: string
}

interface ConceptItem {
  id: string
  canonical_name: string
}

interface Props {
  spaceId: string
  folderId: string
  token: string
  onUnauthorized?: () => void
}

type Mode = 'review' | 'browse'

export default function AnkiDetail({ spaceId, folderId, token, onUnauthorized }: Props) {
  const [mode, setMode] = useState<Mode>('review')
  const [dueCards, setDueCards] = useState<FlashCard[]>([])
  const [allCards, setAllCards] = useState<FlashCard[]>([])
  const [index, setIndex] = useState(0)
  const [flipped, setFlipped] = useState(false)
  const [loading, setLoading] = useState(true)
  const [submitting, setSubmitting] = useState(false)

  // generate modal state
  const [showGenerate, setShowGenerate] = useState(false)
  const [domainInput, setDomainInput] = useState('')
  const [generating, setGenerating] = useState(false)
  const [generateError, setGenerateError] = useState('')
  // concept picker state
  const [topicsWithConcepts, setTopicsWithConcepts] = useState<{ topic: TopicItem; concepts: ConceptItem[] }[]>([])
  const [selectedConceptIds, setSelectedConceptIds] = useState<Set<string>>(new Set())
  const [conceptsLoading, setConceptsLoading] = useState(false)

  const headers = { Authorization: `Bearer ${token}` }

  const fetchDue = useCallback(async () => {
    setLoading(true)
    try {
      const res = await fetch(`${API_URL}/spaces/${spaceId}/flash-cards/due`, { headers })
      if (res.status === 401) { onUnauthorized?.(); return }
      if (!res.ok) return
      const data = await res.json()
      setDueCards(Array.isArray(data) ? data : [])
      setIndex(0)
      setFlipped(false)
    } catch (_) {}
    finally { setLoading(false) }
  }, [spaceId, token])

  const fetchAll = useCallback(async () => {
    setLoading(true)
    try {
      const res = await fetch(`${API_URL}/spaces/${spaceId}/flash-cards`, { headers })
      if (res.status === 401) { onUnauthorized?.(); return }
      if (!res.ok) return
      const data = await res.json()
      setAllCards(Array.isArray(data) ? data : [])
      setIndex(0)
      setFlipped(false)
    } catch (_) {}
    finally { setLoading(false) }
  }, [spaceId, token])

  useEffect(() => {
    if (mode === 'review') fetchDue()
    else fetchAll()
  }, [mode, fetchDue, fetchAll])

  const switchMode = (next: Mode) => {
    setMode(next)
    setIndex(0)
    setFlipped(false)
  }

  const handleRate = async (rating: 'again' | 'hard' | 'good' | 'easy') => {
    const card = dueCards[index]
    if (!card || submitting) return
    setSubmitting(true)
    try {
      await fetch(`${API_URL}/flash-cards/${card.id}/review`, {
        method: 'POST',
        headers: { ...headers, 'Content-Type': 'application/json' },
        body: JSON.stringify({ rating }),
      })
      if (index + 1 < dueCards.length) {
        setIndex((i) => i + 1)
        setFlipped(false)
      } else {
        await fetchDue()
      }
    } catch (_) {}
    finally { setSubmitting(false) }
  }

  const openGenerate = async () => {
    setShowGenerate(true)
    setSelectedConceptIds(new Set())
    setGenerateError('')
    setConceptsLoading(true)
    try {
      const topicsRes = await fetch(`${API_URL}/folders/${folderId}/topics`, { headers })
      if (!topicsRes.ok) { setConceptsLoading(false); return }
      const topics: TopicItem[] = (await topicsRes.json()) ?? []

      const entries = await Promise.all(
        topics.map(async (t) => {
          const res = await fetch(`${API_URL}/topics/${t.id}/concepts`, { headers })
          const concepts: ConceptItem[] = res.ok ? (await res.json()) ?? [] : []
          return { topic: t, concepts }
        })
      )
      setTopicsWithConcepts(entries.filter((e) => e.concepts.length > 0))
    } catch (_) {}
    finally { setConceptsLoading(false) }
  }

  const toggleConcept = (id: string) => {
    setSelectedConceptIds((prev) => {
      const next = new Set(prev)
      next.has(id) ? next.delete(id) : next.add(id)
      return next
    })
  }

  const toggleTopic = (concepts: ConceptItem[]) => {
    const allSelected = concepts.every((c) => selectedConceptIds.has(c.id))
    setSelectedConceptIds((prev) => {
      const next = new Set(prev)
      concepts.forEach((c) => allSelected ? next.delete(c.id) : next.add(c.id))
      return next
    })
  }

  const handleGenerate = async () => {
    const allConcepts = topicsWithConcepts.flatMap((e) => e.concepts)
    const selected = allConcepts
      .filter((c) => selectedConceptIds.has(c.id))
      .map((c) => c.canonical_name)
    if (selected.length === 0) return
    setGenerating(true)
    setGenerateError('')
    try {
      const res = await fetch(`${API_URL}/spaces/${spaceId}/generate-flash-cards`, {
        method: 'POST',
        headers: { ...headers, 'Content-Type': 'application/json' },
        body: JSON.stringify({ concepts: selected, domain: domainInput.trim(), language: 'English' }),
      })
      if (res.status === 401) { onUnauthorized?.(); return }
      if (!res.ok) throw new Error('Failed to generate flash cards')
      setShowGenerate(false)
      setSelectedConceptIds(new Set())
      setDomainInput('')
      if (mode === 'browse') fetchAll()
      else fetchDue()
    } catch (err) {
      setGenerateError((err as Error).message)
    } finally {
      setGenerating(false)
    }
  }

  const generateModal = showGenerate && (
    <div className="modal-overlay" onClick={() => setShowGenerate(false)}>
      <div className="modal-box modal-box-lg" onClick={(e) => e.stopPropagation()}>
        <div className="modal-header">
          <span>Generate Flash Cards from Concepts</span>
          <button className="modal-close" onClick={() => setShowGenerate(false)}>✕</button>
        </div>
        <div className="modal-body">
          {generateError && <div className="error">{generateError}</div>}
          <div className="modal-field">
            <label>Domain (optional)</label>
            <input
              className="modal-input"
              type="text"
              placeholder="e.g. Microsoft Power Platform"
              value={domainInput}
              onChange={(e) => setDomainInput(e.target.value)}
            />
          </div>
          <div className="modal-field">
            <label>
              Select concepts
              {selectedConceptIds.size > 0 && (
                <span className="anki-gen-count"> — {selectedConceptIds.size} selected</span>
              )}
            </label>
            {conceptsLoading ? (
              <p className="anki-flip-hint">Loading concepts…</p>
            ) : topicsWithConcepts.length === 0 ? (
              <p className="anki-flip-hint">No concepts found in this folder's topics.</p>
            ) : (
              <div className="anki-concept-picker">
                {topicsWithConcepts.map(({ topic, concepts }) => {
                  const allSelected = concepts.every((c) => selectedConceptIds.has(c.id))
                  const someSelected = !allSelected && concepts.some((c) => selectedConceptIds.has(c.id))
                  return (
                    <div key={topic.id} className="anki-concept-group">
                      <label className="anki-concept-topic-label">
                        <input
                          type="checkbox"
                          checked={allSelected}
                          ref={(el) => { if (el) el.indeterminate = someSelected }}
                          onChange={() => toggleTopic(concepts)}
                        />
                        <span>{topic.name}</span>
                      </label>
                      <div className="anki-concept-list">
                        {concepts.map((c) => (
                          <label key={c.id} className="anki-concept-item">
                            <input
                              type="checkbox"
                              checked={selectedConceptIds.has(c.id)}
                              onChange={() => toggleConcept(c.id)}
                            />
                            <span>{c.canonical_name}</span>
                          </label>
                        ))}
                      </div>
                    </div>
                  )
                })}
              </div>
            )}
          </div>
          <div className="modal-actions">
            <button onClick={handleGenerate} disabled={generating || selectedConceptIds.size === 0}>
              {generating ? 'Generating…' : `Generate (${selectedConceptIds.size})`}
            </button>
            <button className="secondary" onClick={() => setShowGenerate(false)}>Cancel</button>
          </div>
        </div>
      </div>
    </div>
  )

  const modeTabs = (
    <div className="anki-mode-tabs">
      <button className={mode === 'review' ? 'active' : ''} onClick={() => switchMode('review')}>Review</button>
      <button className={mode === 'browse' ? 'active' : ''} onClick={() => switchMode('browse')}>Browse</button>
      <button className="secondary btn-sm" style={{ marginLeft: 'auto' }} onClick={openGenerate}>+ Generate</button>
    </div>
  )

  if (loading) return <div className="anki-detail">{generateModal}{modeTabs}<p className="anki-flip-hint">Loading…</p></div>

  // ── Browse mode ───────────────────────────────────────────
  if (mode === 'browse') {
    if (allCards.length === 0) {
      return (
        <div className="anki-detail">
          {generateModal}
          {modeTabs}
          <p className="anki-flip-hint">No cards yet.</p>
        </div>
      )
    }
    const card = allCards[index]
    return (
      <div className="anki-detail">
        {generateModal}
        {modeTabs}
        <div className="anki-card" onClick={() => setFlipped((f) => !f)}>
          <div className={`anki-card-inner${flipped ? ' flipped' : ''}`}>
            <div className="anki-card-face anki-card-front">
              <span className="anki-card-label">Question</span>
              <p className="anki-card-text">{card.front}</p>
              {!flipped && <span className="anki-flip-hint">Tap to reveal answer</span>}
            </div>
            <div className="anki-card-face anki-card-back">
              <span className="anki-card-label">Answer</span>
              <p className="anki-card-text">{card.back}</p>
            </div>
          </div>
        </div>
        <div className="anki-nav">
          <button className="secondary" onClick={() => { setIndex((i) => i - 1); setFlipped(false) }} disabled={index === 0}>← Prev</button>
          <span className="anki-nav-counter">{index + 1} / {allCards.length}</span>
          <button className="secondary" onClick={() => { setIndex((i) => i + 1); setFlipped(false) }} disabled={index === allCards.length - 1}>Next →</button>
        </div>
      </div>
    )
  }

  // ── Review mode ───────────────────────────────────────────
  if (dueCards.length === 0) {
    return (
      <div className="anki-detail">
        {generateModal}
        {modeTabs}
        <p className="anki-caught-up">All caught up!</p>
        <p className="anki-flip-hint">No cards due right now. Come back later or add new cards.</p>
        <button className="secondary" style={{ marginTop: '0.75rem' }} onClick={fetchDue}>Refresh</button>
      </div>
    )
  }

  const card = dueCards[index]
  const remaining = dueCards.length - index

  return (
    <div className="anki-detail">
      {generateModal}
      {modeTabs}
      <p className="anki-due-count">{remaining} card{remaining !== 1 ? 's' : ''} due</p>

      <div className="anki-card" onClick={() => setFlipped((f) => !f)}>
        <div className={`anki-card-inner${flipped ? ' flipped' : ''}`}>
          <div className="anki-card-face anki-card-front">
            <span className="anki-card-label">Question</span>
            <p className="anki-card-text">{card.front}</p>
            {!flipped && <span className="anki-flip-hint">Tap to reveal answer</span>}
          </div>
          <div className="anki-card-face anki-card-back">
            <span className="anki-card-label">Answer</span>
            <p className="anki-card-text">{card.back}</p>
          </div>
        </div>
      </div>

      {flipped && (
        <div className="anki-rating-row">
          <button className="anki-rate-btn anki-rate-again" onClick={() => handleRate('again')} disabled={submitting}>Again</button>
          <button className="anki-rate-btn anki-rate-hard"  onClick={() => handleRate('hard')}  disabled={submitting}>Hard</button>
          <button className="anki-rate-btn anki-rate-good"  onClick={() => handleRate('good')}  disabled={submitting}>Good</button>
          <button className="anki-rate-btn anki-rate-easy"  onClick={() => handleRate('easy')}  disabled={submitting}>Easy</button>
        </div>
      )}
    </div>
  )
}
