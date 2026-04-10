import { useCallback, useEffect, useState } from 'react'
import { API_URL } from '../config'

interface AnswerData {
  id: string
  text: string
  is_correct: boolean
  position?: number
}

interface QuestionData {
  id: string
  question_type: string
  body: string
  answers: AnswerData[]
}

interface QuestionDetailProps {
  spaceId: string
  token: string
  onUnauthorized?: () => void
}

export default function QuestionDetail({ spaceId, token, onUnauthorized }: QuestionDetailProps) {
  const [questions, setQuestions] = useState<QuestionData[]>([])
  const [index, setIndex] = useState(0)
  const [selected, setSelected] = useState<Set<string>>(new Set())
  const [revealed, setRevealed] = useState(false)
  const [loading, setLoading] = useState(true)

  const fetchQuestions = useCallback(async () => {
    setLoading(true)
    try {
      const res = await fetch(`${API_URL}/spaces/${spaceId}/questions`, {
        headers: { Authorization: `Bearer ${token}` },
      })
      if (res.status === 401) { onUnauthorized?.(); return }
      if (!res.ok) return
      const data = await res.json()
      setQuestions(Array.isArray(data) ? data : [])
      setIndex(0)
      setSelected(new Set())
      setRevealed(false)
    } catch (_) {}
    finally { setLoading(false) }
  }, [spaceId, token])

  useEffect(() => { fetchQuestions() }, [fetchQuestions])

  const go = (delta: number) => {
    setIndex((i) => i + delta)
    setSelected(new Set())
    setRevealed(false)
  }

  if (loading) return <div className="problem-detail-empty">Loading…</div>
  if (questions.length === 0) return <div className="problem-detail-empty">No questions yet.</div>

  const q = questions[index]
  const isMulti = q.question_type === 'multiple'
  const correctIds = new Set(q.answers.filter((a) => a.is_correct).map((a) => a.id))
  const isCorrect = correctIds.size === selected.size && [...correctIds].every((id) => selected.has(id))

  const toggle = (id: string) => {
    if (revealed) return
    setSelected((prev) => {
      const next = new Set(prev)
      if (isMulti) {
        next.has(id) ? next.delete(id) : next.add(id)
      } else {
        next.clear()
        next.add(id)
      }
      return next
    })
  }

  return (
    <div className="problem-detail">
      <div className="qd-nav-row">
        <span className="qd-counter">{index + 1} / {questions.length}</span>
        <div className="qd-nav-btns">
          <button className="secondary btn-sm" onClick={() => go(-1)} disabled={index === 0}>← Prev</button>
          <button className="secondary btn-sm" onClick={() => go(1)} disabled={index === questions.length - 1}>Next →</button>
        </div>
      </div>

      <section className="problem-detail-section">
        <span className="question-type-badge">{q.question_type.replace('_', ' ')}</span>
        {isMulti && <span className="qd-multi-hint">Select all that apply</span>}
        <p className="problem-detail-body" style={{ marginTop: '0.75rem' }}>{q.body}</p>
      </section>

      {q.answers.length > 0 && (
        <section className="problem-detail-section">
          <ul className="question-answers-list">
            {q.answers.map((ans) => {
              const isSelected = selected.has(ans.id)
              let cls = 'question-answer-item'
              if (revealed) {
                if (ans.is_correct) cls += ' correct'
                else if (isSelected) cls += ' wrong'
              } else if (isSelected) {
                cls += ' selected'
              }
              const marker = revealed
                ? (ans.is_correct ? '✓' : isSelected ? '✗' : '○')
                : (isSelected ? (isMulti ? '☑' : '●') : (isMulti ? '☐' : '○'))
              return (
                <li
                  key={ans.id}
                  className={cls}
                  onClick={() => toggle(ans.id)}
                  style={{ cursor: revealed ? 'default' : 'pointer' }}
                >
                  <span className="question-answer-marker">{marker}</span>
                  <span className="question-answer-text">{ans.text}</span>
                </li>
              )
            })}
          </ul>
          <div className="qd-actions">
            {!revealed ? (
              <button onClick={() => setRevealed(true)} disabled={selected.size === 0}>Check answer</button>
            ) : (
              <p className="qd-result">
                {isCorrect ? '✓ Correct!' : '✗ Incorrect'}
              </p>
            )}
          </div>
        </section>
      )}
    </div>
  )
}
