import { useState } from 'react'
import { API_URL } from '../config'

interface Props {
  space: { id: string; name: string }
  token: string
  onUnauthorized?: () => void
  onSaved: () => void
  onClose: () => void
}

export default function AnkiModal({ space, token, onUnauthorized, onSaved, onClose }: Props) {
  const [front, setFront] = useState('')
  const [back, setBack] = useState('')
  const [saving, setSaving] = useState(false)
  const [error, setError] = useState('')

  const headers = { Authorization: `Bearer ${token}`, 'Content-Type': 'application/json' }

  const handleSubmit = async (e: React.FormEvent) => {
    e.preventDefault()
    setSaving(true)
    setError('')
    try {
      // Create flash card directly on the space
      const cardRes = await fetch(`${API_URL}/spaces/${space.id}/flash-cards`, {
        method: 'POST',
        headers,
        body: JSON.stringify({ front: front.trim(), back: back.trim() }),
      })
      if (cardRes.status === 401) { onUnauthorized?.(); return }
      if (!cardRes.ok) throw new Error('Failed to create flash card')

      onSaved()
    } catch (err) {
      setError((err as Error).message)
    } finally {
      setSaving(false)
    }
  }

  return (
    <div className="modal-overlay" onClick={onClose}>
      <div className="modal-box" onClick={(e) => e.stopPropagation()}>
        <div className="modal-header">
          <span>New Flash Card</span>
          <button className="modal-close" onClick={onClose}>✕</button>
        </div>
        <form className="modal-body" onSubmit={handleSubmit}>
          {error && <div className="error">{error}</div>}
          <div className="modal-field">
            <label>Front (question / prompt)</label>
            <textarea
              className="modal-textarea"
              autoFocus
              required
              rows={3}
              value={front}
              onChange={(e) => setFront(e.target.value)}
              placeholder="What is the question or prompt?"
            />
          </div>
          <div className="modal-field">
            <label>Back (answer)</label>
            <textarea
              className="modal-textarea"
              rows={4}
              value={back}
              onChange={(e) => setBack(e.target.value)}
              placeholder="The answer or explanation"
            />
          </div>
          <div className="modal-actions">
            <button type="submit" disabled={saving}>{saving ? 'Saving…' : 'Create'}</button>
            <button type="button" className="secondary" onClick={onClose}>Cancel</button>
          </div>
        </form>
      </div>
    </div>
  )
}
