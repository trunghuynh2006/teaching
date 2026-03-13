import { useCallback, useEffect, useState } from 'react'
import { API_URL } from '../config'

interface AnkiReviewProps {
  token: string
  onUnauthorized: () => void
}

interface AnkiCard {
  id: string
  front_text: string
  back_text: string
  bloom_level: string | null
  tags: string[]
  interval_days: number
  repetitions: number
  ease_factor: string
  due_at: string | null
}

type Rating = 'again' | 'hard' | 'good' | 'easy'

const RATING_CONFIG: { rating: Rating; label: string; color: string; hint: string }[] = [
  { rating: 'again', label: 'Again', color: '#e53935', hint: '<1d' },
  { rating: 'hard', label: 'Hard',  color: '#fb8c00', hint: '~1d' },
  { rating: 'good', label: 'Good',  color: '#43a047', hint: '~4d' },
  { rating: 'easy', label: 'Easy',  color: '#1e88e5', hint: '~1w+' },
]

const BLOOM_COLORS: Record<string, string> = {
  remember:   '#e3f2fd',
  understand: '#e8f5e9',
  apply:      '#fff3e0',
  analyze:    '#f3e5f5',
  evaluate:   '#fce4ec',
  create:     '#e0f7fa',
}

export default function AnkiReview({ token, onUnauthorized }: AnkiReviewProps) {
  const [queue, setQueue] = useState<AnkiCard[]>([])
  const [currentIndex, setCurrentIndex] = useState(0)
  const [flipped, setFlipped] = useState(false)
  const [loading, setLoading] = useState(true)
  const [submitting, setSubmitting] = useState(false)
  const [error, setError] = useState('')
  const [sessionDone, setSessionDone] = useState(false)
  const [reviewed, setReviewed] = useState(0)

  const loadCards = useCallback(async () => {
    setLoading(true)
    setError('')
    try {
      const res = await fetch(`${API_URL}/anki/cards/due`, {
        headers: { Authorization: `Bearer ${token}` },
      })
      if (res.status === 401) { onUnauthorized(); return }
      if (!res.ok) { setError('Failed to load cards.'); return }
      const data = await res.json()
      setQueue(data.cards ?? [])
      setCurrentIndex(0)
      setFlipped(false)
      setSessionDone(false)
      setReviewed(0)
    } catch {
      setError('Network error.')
    } finally {
      setLoading(false)
    }
  }, [token, onUnauthorized])

  useEffect(() => { loadCards() }, [loadCards])

  async function submitRating(rating: Rating) {
    const card = queue[currentIndex]
    if (!card || submitting) return

    setSubmitting(true)
    try {
      const res = await fetch(`${API_URL}/anki/cards/${card.id}/review`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json', Authorization: `Bearer ${token}` },
        body: JSON.stringify({ rating }),
      })
      if (res.status === 401) { onUnauthorized(); return }
      if (!res.ok) { setError('Failed to submit review.'); return }

      const nextIndex = currentIndex + 1
      setReviewed(r => r + 1)
      if (nextIndex >= queue.length) {
        setSessionDone(true)
      } else {
        setCurrentIndex(nextIndex)
        setFlipped(false)
      }
    } catch {
      setError('Network error.')
    } finally {
      setSubmitting(false)
    }
  }

  if (loading) {
    return <div style={styles.container}><p>Loading cards…</p></div>
  }

  if (error) {
    return (
      <div style={styles.container}>
        <p style={{ color: 'red' }}>{error}</p>
        <button onClick={loadCards}>Retry</button>
      </div>
    )
  }

  if (sessionDone || queue.length === 0) {
    return (
      <div style={{ ...styles.container, textAlign: 'center' }}>
        <div style={{ fontSize: '3rem', marginBottom: '0.5rem' }}>🎉</div>
        <h2 style={{ marginTop: 0 }}>
          {queue.length === 0 ? 'No cards due!' : `Session complete!`}
        </h2>
        {reviewed > 0 && (
          <p style={{ color: '#555' }}>Reviewed {reviewed} card{reviewed !== 1 ? 's' : ''}.</p>
        )}
        {queue.length === 0 && (
          <p style={{ color: '#555' }}>All cards are up to date. Come back later.</p>
        )}
        <button onClick={loadCards} style={styles.refreshBtn}>Start New Session</button>
      </div>
    )
  }

  const card = queue[currentIndex]
  const progress = `${currentIndex + 1} / ${queue.length}`

  return (
    <div style={styles.container}>
      <div style={styles.header}>
        <h2 style={{ margin: 0 }}>Anki Review</h2>
        <span style={styles.progress}>{progress}</span>
      </div>

      <div style={styles.progressBar}>
        <div style={{ ...styles.progressFill, width: `${(currentIndex / queue.length) * 100}%` }} />
      </div>

      {/* Card */}
      <div
        style={styles.card}
        onClick={() => !flipped && setFlipped(true)}
        role="button"
        tabIndex={0}
        onKeyDown={e => e.key === 'Enter' || e.key === ' ' ? setFlipped(true) : undefined}
      >
        {/* Bloom badge + tags */}
        <div style={{ display: 'flex', gap: '0.4rem', flexWrap: 'wrap', marginBottom: '0.75rem' }}>
          {card.bloom_level && (
            <span style={{
              fontSize: '0.7rem', fontWeight: 700, textTransform: 'uppercase',
              padding: '2px 7px', borderRadius: '3px',
              background: BLOOM_COLORS[card.bloom_level] ?? '#f0f0f0',
              letterSpacing: '0.05em',
            }}>
              {card.bloom_level}
            </span>
          )}
          {card.tags?.map(tag => (
            <span key={tag} style={{ fontSize: '0.75rem', color: '#666', background: '#f0f0f0', padding: '1px 6px', borderRadius: '3px' }}>
              {tag}
            </span>
          ))}
        </div>

        <div style={styles.sideLabel}>FRONT</div>
        <div style={styles.cardText}>{card.front_text}</div>

        {!flipped ? (
          <div style={styles.tapHint}>Tap to reveal answer</div>
        ) : (
          <>
            <div style={styles.divider} />
            <div style={styles.sideLabel}>BACK</div>
            <div style={styles.cardText}>{card.back_text}</div>
          </>
        )}
      </div>

      {/* Rating buttons — only shown after flip */}
      {flipped && (
        <div style={styles.ratingRow}>
          {RATING_CONFIG.map(({ rating, label, color, hint }) => (
            <button
              key={rating}
              onClick={() => submitRating(rating)}
              disabled={submitting}
              style={{ ...styles.ratingBtn, borderColor: color, color }}
            >
              <span style={{ fontWeight: 700 }}>{label}</span>
              <span style={{ fontSize: '0.7rem', opacity: 0.7 }}>{hint}</span>
            </button>
          ))}
        </div>
      )}

      {error && <p style={{ color: 'red', marginTop: '0.5rem' }}>{error}</p>}
    </div>
  )
}

const styles: Record<string, React.CSSProperties> = {
  container: {
    padding: '1.5rem',
    maxWidth: '600px',
    margin: '0 auto',
  },
  header: {
    display: 'flex',
    justifyContent: 'space-between',
    alignItems: 'center',
    marginBottom: '0.5rem',
  },
  progress: {
    fontSize: '0.9rem',
    color: '#666',
  },
  progressBar: {
    height: '4px',
    background: '#e0e0e0',
    borderRadius: '2px',
    marginBottom: '1.25rem',
    overflow: 'hidden',
  },
  progressFill: {
    height: '100%',
    background: '#1e88e5',
    borderRadius: '2px',
    transition: 'width 0.3s ease',
  },
  card: {
    border: '1px solid #ddd',
    borderRadius: '10px',
    padding: '1.5rem',
    minHeight: '200px',
    background: '#fff',
    cursor: 'pointer',
    userSelect: 'none',
    boxShadow: '0 2px 8px rgba(0,0,0,0.06)',
  },
  sideLabel: {
    fontSize: '0.65rem',
    fontWeight: 700,
    color: '#aaa',
    letterSpacing: '0.08em',
    textTransform: 'uppercase',
    marginBottom: '0.4rem',
  },
  cardText: {
    fontSize: '1.1rem',
    lineHeight: 1.55,
    whiteSpace: 'pre-wrap',
  },
  tapHint: {
    marginTop: '2rem',
    textAlign: 'center',
    color: '#bbb',
    fontSize: '0.85rem',
  },
  divider: {
    borderTop: '1px dashed #e0e0e0',
    margin: '1.25rem 0',
  },
  ratingRow: {
    display: 'flex',
    gap: '0.75rem',
    marginTop: '1rem',
    justifyContent: 'center',
  },
  ratingBtn: {
    flex: 1,
    display: 'flex',
    flexDirection: 'column',
    alignItems: 'center',
    gap: '2px',
    padding: '0.6rem 0.25rem',
    border: '2px solid',
    borderRadius: '8px',
    background: 'transparent',
    cursor: 'pointer',
    fontSize: '0.9rem',
    transition: 'background 0.15s',
  },
  refreshBtn: {
    padding: '0.6rem 1.5rem',
    fontSize: '1rem',
    borderRadius: '6px',
    border: '1px solid #1e88e5',
    color: '#1e88e5',
    background: 'transparent',
    cursor: 'pointer',
  },
}
