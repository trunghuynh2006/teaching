import { useState } from 'react'
import { API_URL } from '../config'

interface AnkiCardGeneratorProps {
  token: string
  onUnauthorized: () => void
}

interface GeneratedCard {
  front_text: string
  back_text: string
  bloom_level: string
  tags?: string[]
}

type CardDecision = 'approved' | 'rejected' | 'pending'

interface ReviewCard extends GeneratedCard {
  decision: CardDecision
}

const BLOOM_COLORS: Record<string, string> = {
  remember: '#e3f2fd',
  understand: '#e8f5e9',
  apply: '#fff3e0',
  analyze: '#f3e5f5',
  evaluate: '#fce4ec',
  create: '#e0f7fa',
}

export default function AnkiCardGenerator({ token, onUnauthorized }: AnkiCardGeneratorProps) {
  const [sourceText, setSourceText] = useState('')
  const [language, setLanguage] = useState('English')
  const [cards, setCards] = useState<ReviewCard[]>([])
  const [generating, setGenerating] = useState(false)
  const [error, setError] = useState('')
  const [notice, setNotice] = useState('')

  async function handleGenerate(e: React.FormEvent) {
    e.preventDefault()
    if (!sourceText.trim()) return

    setGenerating(true)
    setError('')
    setNotice('')
    setCards([])

    try {
      const res = await fetch(`${API_URL}/ai/anki-cards`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json', Authorization: `Bearer ${token}` },
        body: JSON.stringify({ source_text: sourceText.trim(), language }),
      })

      if (res.status === 401) { onUnauthorized(); return }
      if (!res.ok) {
        const err = await res.json().catch(() => ({}))
        setError(err.detail || res.statusText)
        return
      }

      const data = await res.json()
      setCards((data.cards as GeneratedCard[]).map(c => ({ ...c, decision: 'pending' })))
    } catch {
      setError('Network error — could not reach the server.')
    } finally {
      setGenerating(false)
    }
  }

  function setDecision(index: number, decision: CardDecision) {
    setCards(prev => prev.map((c, i) => i === index ? { ...c, decision } : c))
  }

  function approveAll() {
    setCards(prev => prev.map(c => ({ ...c, decision: 'approved' })))
  }

  function rejectAll() {
    setCards(prev => prev.map(c => ({ ...c, decision: 'rejected' })))
  }

  async function handleSave() {
    const approved = cards.filter(c => c.decision === 'approved')
    if (approved.length === 0) {
      setError('No cards approved.')
      return
    }

    setError('')
    setNotice('')

    try {
      const res = await fetch(`${API_URL}/anki/cards/bulk`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json', Authorization: `Bearer ${token}` },
        body: JSON.stringify({ cards: approved.map(({ decision: _, ...c }) => c) }),
      })

      if (res.status === 401) { onUnauthorized(); return }
      if (!res.ok) {
        const err = await res.json().catch(() => ({}))
        setError(err.detail || res.statusText)
        return
      }

      setNotice(`${approved.length} card${approved.length !== 1 ? 's' : ''} saved.`)
      setCards([])
      setSourceText('')
    } catch {
      setError('Network error — could not save cards.')
    }
  }

  const approvedCount = cards.filter(c => c.decision === 'approved').length
  const pendingCount = cards.filter(c => c.decision === 'pending').length

  return (
    <div style={{ padding: '1.5rem', maxWidth: '860px' }}>
      <h2 style={{ marginTop: 0 }}>Anki Card Generator</h2>

      <form onSubmit={handleGenerate} style={{ marginBottom: '1.5rem' }}>
        <div style={{ marginBottom: '0.75rem' }}>
          <label style={{ display: 'block', marginBottom: '0.25rem', fontWeight: 600 }}>
            Article / Lesson Text
          </label>
          <textarea
            value={sourceText}
            onChange={e => setSourceText(e.target.value)}
            rows={8}
            placeholder="Paste your article or lesson content here…"
            style={{ width: '100%', boxSizing: 'border-box', padding: '0.5rem', fontFamily: 'inherit', fontSize: '0.9rem', resize: 'vertical' }}
            disabled={generating}
          />
        </div>

        <div style={{ display: 'flex', gap: '1rem', alignItems: 'center' }}>
          <label style={{ fontWeight: 600 }}>
            Language:&nbsp;
            <select value={language} onChange={e => setLanguage(e.target.value)} disabled={generating}>
              <option>English</option>
              <option>Vietnamese</option>
              <option>French</option>
              <option>Spanish</option>
              <option>German</option>
              <option>Japanese</option>
            </select>
          </label>
          <button type="submit" disabled={generating || !sourceText.trim()}>
            {generating ? 'Generating…' : 'Generate Cards'}
          </button>
        </div>
      </form>

      {error && <div style={{ color: 'red', marginBottom: '1rem' }}>{error}</div>}
      {notice && <div style={{ color: 'green', marginBottom: '1rem' }}>{notice}</div>}

      {cards.length > 0 && (
        <>
          <div style={{ display: 'flex', gap: '0.75rem', alignItems: 'center', marginBottom: '1rem', flexWrap: 'wrap' }}>
            <strong>{cards.length} cards generated</strong>
            <span style={{ color: '#666' }}>·</span>
            <span style={{ color: 'green' }}>{approvedCount} approved</span>
            <span style={{ color: '#666' }}>·</span>
            <span style={{ color: '#888' }}>{pendingCount} pending</span>
            <span style={{ flex: 1 }} />
            <button type="button" onClick={approveAll}>Approve All</button>
            <button type="button" onClick={rejectAll}>Reject All</button>
            <button
              type="button"
              onClick={handleSave}
              disabled={approvedCount === 0}
              style={{ fontWeight: 600 }}
            >
              Save {approvedCount > 0 ? `${approvedCount} ` : ''}Approved
            </button>
          </div>

          <div style={{ display: 'flex', flexDirection: 'column', gap: '0.75rem' }}>
            {cards.map((card, i) => (
              <div
                key={i}
                style={{
                  border: '1px solid',
                  borderColor: card.decision === 'approved' ? '#4caf50' : card.decision === 'rejected' ? '#ccc' : '#ddd',
                  borderRadius: '6px',
                  padding: '0.75rem 1rem',
                  opacity: card.decision === 'rejected' ? 0.45 : 1,
                  background: card.decision === 'approved' ? '#f9fff9' : '#fff',
                }}
              >
                <div style={{ display: 'flex', gap: '0.5rem', alignItems: 'flex-start' }}>
                  <div style={{ flex: 1 }}>
                    <div style={{ display: 'flex', gap: '0.5rem', alignItems: 'center', marginBottom: '0.4rem', flexWrap: 'wrap' }}>
                      <span
                        style={{
                          fontSize: '0.7rem',
                          fontWeight: 700,
                          textTransform: 'uppercase',
                          padding: '2px 7px',
                          borderRadius: '3px',
                          background: BLOOM_COLORS[card.bloom_level] ?? '#f0f0f0',
                          letterSpacing: '0.05em',
                        }}
                      >
                        {card.bloom_level}
                      </span>
                      {card.tags?.map(tag => (
                        <span key={tag} style={{ fontSize: '0.75rem', color: '#666', background: '#f0f0f0', padding: '1px 6px', borderRadius: '3px' }}>
                          {tag}
                        </span>
                      ))}
                    </div>

                    <div style={{ display: 'grid', gridTemplateColumns: '1fr 1fr', gap: '0.75rem' }}>
                      <div>
                        <div style={{ fontSize: '0.7rem', fontWeight: 700, color: '#888', textTransform: 'uppercase', marginBottom: '0.2rem' }}>Front</div>
                        <div style={{ fontSize: '0.9rem' }}>{card.front_text}</div>
                      </div>
                      <div>
                        <div style={{ fontSize: '0.7rem', fontWeight: 700, color: '#888', textTransform: 'uppercase', marginBottom: '0.2rem' }}>Back</div>
                        <div style={{ fontSize: '0.9rem' }}>{card.back_text}</div>
                      </div>
                    </div>
                  </div>

                  <div style={{ display: 'flex', flexDirection: 'column', gap: '0.35rem', flexShrink: 0 }}>
                    <button
                      type="button"
                      onClick={() => setDecision(i, card.decision === 'approved' ? 'pending' : 'approved')}
                      style={{
                        padding: '3px 10px',
                        fontSize: '0.8rem',
                        background: card.decision === 'approved' ? '#4caf50' : 'transparent',
                        color: card.decision === 'approved' ? '#fff' : '#4caf50',
                        border: '1px solid #4caf50',
                        borderRadius: '4px',
                        cursor: 'pointer',
                      }}
                    >
                      ✓ Approve
                    </button>
                    <button
                      type="button"
                      onClick={() => setDecision(i, card.decision === 'rejected' ? 'pending' : 'rejected')}
                      style={{
                        padding: '3px 10px',
                        fontSize: '0.8rem',
                        background: card.decision === 'rejected' ? '#e53935' : 'transparent',
                        color: card.decision === 'rejected' ? '#fff' : '#e53935',
                        border: '1px solid #e53935',
                        borderRadius: '4px',
                        cursor: 'pointer',
                      }}
                    >
                      ✗ Reject
                    </button>
                  </div>
                </div>
              </div>
            ))}
          </div>
        </>
      )}
    </div>
  )
}
