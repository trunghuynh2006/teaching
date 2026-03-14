import { useState } from 'react'
import { API_URL } from '../config'
import type { SpaceItemData } from './SpaceItemsSidebar'

interface ProblemModalProps {
  space: { id: string; name: string }
  token: string
  onUnauthorized?: () => void
  onSaved: (item: SpaceItemData) => void
  onClose: () => void
}

async function parseError(res: Response): Promise<string> {
  try {
    const p = await res.json()
    if (p?.detail) return p.detail
  } catch (_) {}
  return res.statusText || 'Request failed'
}

export default function ProblemModal({ space, token, onUnauthorized, onSaved, onClose }: ProblemModalProps) {
  const [question, setQuestion] = useState('')
  const [solution, setSolution] = useState('')
  const [steps, setSteps] = useState([''])
  const [saving, setSaving] = useState(false)
  const [error, setError] = useState('')

  const headers = { Authorization: `Bearer ${token}`, 'Content-Type': 'application/json' }

  const addStep = () => setSteps((prev) => [...prev, ''])
  const removeStep = (idx: number) => setSteps((prev) => prev.filter((_, i) => i !== idx))
  const updateStep = (idx: number, val: string) =>
    setSteps((prev) => prev.map((s, i) => (i === idx ? val : s)))

  const handleSubmit = async (e: React.FormEvent) => {
    e.preventDefault()
    const q = question.trim()
    if (!q) { setError('Question is required'); return }
    setSaving(true)
    setError('')
    try {
      // 1. Create SpaceItem
      const siRes = await fetch(`${API_URL}/spaces/${space.id}/items`, {
        method: 'POST',
        headers,
        body: JSON.stringify({ title: q.slice(0, 100), content: '' }),
      })
      if (siRes.status === 401) { onUnauthorized?.(); return }
      if (!siRes.ok) throw new Error(await parseError(siRes))
      const spaceItem: SpaceItemData = await siRes.json()

      // 2. Create Problem
      const probRes = await fetch(`${API_URL}/space-items/${spaceItem.id}/problems`, {
        method: 'POST',
        headers,
        body: JSON.stringify({ question: q, solution: solution.trim() }),
      })
      if (probRes.status === 401) { onUnauthorized?.(); return }
      if (!probRes.ok) throw new Error(await parseError(probRes))
      const problem = await probRes.json()

      // 3. Create Steps (best-effort)
      const nonEmptySteps = steps.map((s) => s.trim()).filter(Boolean)
      for (const body of nonEmptySteps) {
        const stepRes = await fetch(`${API_URL}/problems/${problem.id}/steps`, {
          method: 'POST',
          headers,
          body: JSON.stringify({ body }),
        })
        if (stepRes.status === 401) { onUnauthorized?.(); return }
      }

      onSaved(spaceItem)
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
          <span>New Problem</span>
          <button className="modal-close" type="button" onClick={onClose}>✕</button>
        </div>

        <form className="modal-body" onSubmit={handleSubmit}>
          {error && <div className="error">{error}</div>}

          <label className="modal-field">
            Question
            <textarea
              autoFocus
              className="modal-textarea"
              value={question}
              onChange={(e) => setQuestion(e.target.value)}
              placeholder="Describe the problem…"
              rows={3}
              required
            />
          </label>

          <div className="modal-steps-section">
            <div className="modal-steps-header">
              <span>Steps</span>
              <button type="button" className="modal-add-step-btn" onClick={addStep}>+ Add step</button>
            </div>
            {steps.map((step, idx) => (
              <div className="modal-step-row" key={idx}>
                <span className="modal-step-index">{idx + 1}</span>
                <textarea
                  className="modal-textarea modal-step-textarea"
                  value={step}
                  onChange={(e) => updateStep(idx, e.target.value)}
                  placeholder={`Step ${idx + 1}…`}
                  rows={2}
                />
                {steps.length > 1 && (
                  <button type="button" className="modal-remove-step-btn" onClick={() => removeStep(idx)}>✕</button>
                )}
              </div>
            ))}
          </div>

          <label className="modal-field">
            Solution (optional)
            <textarea
              className="modal-textarea"
              value={solution}
              onChange={(e) => setSolution(e.target.value)}
              placeholder="Brief summary of the answer…"
              rows={2}
            />
          </label>

          <div className="modal-actions">
            <button type="submit" disabled={saving}>{saving ? 'Saving…' : 'Create Problem'}</button>
            <button type="button" className="secondary" onClick={onClose}>Cancel</button>
          </div>
        </form>
      </div>
    </div>
  )
}
