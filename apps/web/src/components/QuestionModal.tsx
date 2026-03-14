import { useState } from 'react'
import { API_URL } from '../config'
import type { SpaceItemData } from './SpaceItemsSidebar'

const QUESTION_TYPES = ['multiple_choice', 'true_false', 'short_answer', 'fill_blank']

interface AnswerDraft {
  text: string
  isCorrect: boolean
}

interface QuestionModalProps {
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

export default function QuestionModal({ space, token, onUnauthorized, onSaved, onClose }: QuestionModalProps) {
  const [questionType, setQuestionType] = useState('multiple_choice')
  const [body, setBody] = useState('')
  const [answers, setAnswers] = useState<AnswerDraft[]>([
    { text: '', isCorrect: false },
    { text: '', isCorrect: false },
  ])
  const [saving, setSaving] = useState(false)
  const [error, setError] = useState('')

  const headers = { Authorization: `Bearer ${token}`, 'Content-Type': 'application/json' }

  const addAnswer = () => setAnswers((prev) => [...prev, { text: '', isCorrect: false }])
  const removeAnswer = (idx: number) => setAnswers((prev) => prev.filter((_, i) => i !== idx))
  const updateAnswerText = (idx: number, text: string) =>
    setAnswers((prev) => prev.map((a, i) => (i === idx ? { ...a, text } : a)))
  const toggleCorrect = (idx: number) =>
    setAnswers((prev) => prev.map((a, i) => (i === idx ? { ...a, isCorrect: !a.isCorrect } : a)))

  const handleSubmit = async (e: React.FormEvent) => {
    e.preventDefault()
    const b = body.trim()
    if (!b) { setError('Question body is required'); return }
    setSaving(true)
    setError('')
    try {
      // 1. Create SpaceItem
      const siRes = await fetch(`${API_URL}/spaces/${space.id}/items`, {
        method: 'POST',
        headers,
        body: JSON.stringify({ title: b.slice(0, 100), content: '' }),
      })
      if (siRes.status === 401) { onUnauthorized?.(); return }
      if (!siRes.ok) throw new Error(await parseError(siRes))
      const spaceItem: SpaceItemData = await siRes.json()

      // 2. Create Question
      const qRes = await fetch(`${API_URL}/space-items/${spaceItem.id}/questions`, {
        method: 'POST',
        headers,
        body: JSON.stringify({ question_type: questionType, body: b }),
      })
      if (qRes.status === 401) { onUnauthorized?.(); return }
      if (!qRes.ok) throw new Error(await parseError(qRes))
      const question = await qRes.json()

      // 3. Create Answers (best-effort)
      for (const ans of answers.filter((a) => a.text.trim())) {
        const aRes = await fetch(`${API_URL}/questions/${question.id}/answers`, {
          method: 'POST',
          headers,
          body: JSON.stringify({ text: ans.text.trim(), is_correct: ans.isCorrect }),
        })
        if (aRes.status === 401) { onUnauthorized?.(); return }
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
          <span>New Question</span>
          <button className="modal-close" type="button" onClick={onClose}>✕</button>
        </div>

        <form className="modal-body" onSubmit={handleSubmit}>
          {error && <div className="error">{error}</div>}

          <label className="modal-field">
            Type
            <select
              className="modal-select"
              value={questionType}
              onChange={(e) => setQuestionType(e.target.value)}
            >
              {QUESTION_TYPES.map((t) => (
                <option key={t} value={t}>{t.replace('_', ' ')}</option>
              ))}
            </select>
          </label>

          <label className="modal-field">
            Question
            <textarea
              autoFocus
              className="modal-textarea"
              value={body}
              onChange={(e) => setBody(e.target.value)}
              placeholder="Write the question…"
              rows={3}
              required
            />
          </label>

          <div className="modal-steps-section">
            <div className="modal-steps-header">
              <span>Answers</span>
              <button type="button" className="modal-add-step-btn" onClick={addAnswer}>+ Add answer</button>
            </div>
            {answers.map((ans, idx) => (
              <div className="modal-answer-row" key={idx}>
                <input
                  type="checkbox"
                  className="modal-answer-correct"
                  checked={ans.isCorrect}
                  onChange={() => toggleCorrect(idx)}
                  title="Mark as correct"
                />
                <input
                  className="modal-answer-input"
                  value={ans.text}
                  onChange={(e) => updateAnswerText(idx, e.target.value)}
                  placeholder={`Answer ${idx + 1}…`}
                />
                {answers.length > 1 && (
                  <button type="button" className="modal-remove-step-btn" onClick={() => removeAnswer(idx)}>✕</button>
                )}
              </div>
            ))}
            <p className="modal-answer-hint">Check the box to mark an answer as correct.</p>
          </div>

          <div className="modal-actions">
            <button type="submit" disabled={saving}>{saving ? 'Saving…' : 'Create Question'}</button>
            <button type="button" className="secondary" onClick={onClose}>Cancel</button>
          </div>
        </form>
      </div>
    </div>
  )
}
