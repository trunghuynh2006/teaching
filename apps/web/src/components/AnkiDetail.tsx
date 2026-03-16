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
  const [card, setCard] = useState<FlashCard | null>(null)
  const [flipped, setFlipped] = useState(false)
  const [loading, setLoading] = useState(true)
  const [error, setError] = useState('')

  const fetchCard = useCallback(async () => {
    setLoading(true)
    setError('')
    try {
      const res = await fetch(`${API_URL}/spaces/${spaceId}/flash-cards`, {
        headers: { Authorization: `Bearer ${token}` },
      })
      if (res.status === 401) { onUnauthorized?.(); return }
      if (!res.ok) throw new Error('Failed to load flash card')
      const data = await res.json()
      const list: FlashCard[] = Array.isArray(data) ? data : []
      setCard(list[0] ?? null)
      setFlipped(false)
    } catch (err) {
      setError((err as Error).message)
    } finally {
      setLoading(false)
    }
  }, [spaceId, token])

  useEffect(() => { fetchCard() }, [fetchCard])

  if (loading) return <div className="space-item-detail"><p className="space-item-detail-empty">Loading…</p></div>
  if (error) return <div className="space-item-detail"><p className="error">{error}</p></div>
  if (!card) return <div className="space-item-detail"><p className="space-item-detail-empty">No flash card found.</p></div>

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
    </div>
  )
}
