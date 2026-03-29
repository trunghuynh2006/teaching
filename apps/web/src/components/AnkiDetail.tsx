import { useCallback, useEffect, useState } from 'react'
import { API_URL } from '../config'

interface FlashCard {
  id: string
  front: string
  back: string
}

interface Props {
  spaceId: string
  token: string
  onUnauthorized?: () => void
}

export default function AnkiDetail({ spaceId, token, onUnauthorized }: Props) {
  const [cards, setCards] = useState<FlashCard[]>([])
  const [index, setIndex] = useState(0)
  const [flipped, setFlipped] = useState(false)
  const [loading, setLoading] = useState(true)
  const [error, setError] = useState('')

  const fetchCards = useCallback(async () => {
    setLoading(true)
    setError('')
    try {
      const res = await fetch(`${API_URL}/spaces/${spaceId}/flash-cards`, {
        headers: { Authorization: `Bearer ${token}` },
      })
      if (res.status === 401) { onUnauthorized?.(); return }
      if (!res.ok) throw new Error('Failed to load flash cards')
      const data = await res.json()
      setCards(Array.isArray(data) ? data : [])
      setIndex(0)
      setFlipped(false)
    } catch (err) {
      setError((err as Error).message)
    } finally {
      setLoading(false)
    }
  }, [spaceId, token])

  useEffect(() => { fetchCards() }, [fetchCards])

  const go = (delta: number) => {
    setIndex((i) => i + delta)
    setFlipped(false)
  }

  if (loading) return <div className="space-item-detail"><p className="space-item-detail-empty">Loading…</p></div>
  if (error) return <div className="space-item-detail"><p className="error">{error}</p></div>
  if (cards.length === 0) return <div className="space-item-detail"><p className="space-item-detail-empty">No flash cards yet.</p></div>

  const card = cards[index]

  return (
    <div className="anki-detail">
      <div className="anki-card" onClick={() => setFlipped((f) => !f)}>
        <div className={`anki-card-inner${flipped ? ' flipped' : ''}`}>
          <div className="anki-card-face anki-card-front">
            <span className="anki-card-label">Front</span>
            <p className="anki-card-text">{card.front}</p>
          </div>
          <div className="anki-card-face anki-card-back">
            <span className="anki-card-label">Back</span>
            <p className="anki-card-text">{card.back || <em>No answer provided.</em>}</p>
          </div>
        </div>
      </div>
      <p className="anki-flip-hint">{flipped ? 'Click to see front' : 'Click to flip'}</p>

      <div className="anki-nav">
        <button className="secondary" onClick={() => go(-1)} disabled={index === 0}>← Prev</button>
        <span className="anki-nav-counter">{index + 1} / {cards.length}</span>
        <button className="secondary" onClick={() => go(1)} disabled={index === cards.length - 1}>Next →</button>
      </div>
    </div>
  )
}
