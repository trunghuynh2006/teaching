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

interface Props {
  spaceId: string
  token: string
  onUnauthorized?: () => void
}

export default function AnkiDetail({ spaceId, token, onUnauthorized }: Props) {
  const [dueCards, setDueCards] = useState<FlashCard[]>([])
  const [index, setIndex] = useState(0)
  const [flipped, setFlipped] = useState(false)
  const [loading, setLoading] = useState(true)
  const [submitting, setSubmitting] = useState(false)

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

  useEffect(() => { fetchDue() }, [fetchDue])

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

  if (loading) return <div className="anki-detail"><p className="anki-flip-hint">Loading…</p></div>

  if (dueCards.length === 0) {
    return (
      <div className="anki-detail">
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
