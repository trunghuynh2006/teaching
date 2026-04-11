import { useCallback, useEffect, useRef, useState } from 'react'
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

interface AttemptItem {
  id: string
  question_id: string
  selected_answer_ids: string[]
  is_correct: boolean
  answered_at: string
}

// per-question summary derived from all attempts
interface QuestionHistory {
  total: number
  correct: number
  lastCorrect: boolean | null  // null = never attempted
}

interface QuestionDetailProps {
  spaceId: string
  token: string
  onUnauthorized?: () => void
}

function buildHistoryMap(attempts: AttemptItem[]): Map<string, QuestionHistory> {
  const m = new Map<string, QuestionHistory>()
  // attempts are newest-first
  for (const a of attempts) {
    const existing = m.get(a.question_id)
    if (!existing) {
      m.set(a.question_id, { total: 1, correct: a.is_correct ? 1 : 0, lastCorrect: a.is_correct })
    } else {
      existing.total++
      if (a.is_correct) existing.correct++
    }
  }
  return m
}

// Priority score: higher = surface sooner.
// Never attempted (2) > last wrong + low accuracy (1…) > last correct (negative).
function priorityScore(h: QuestionHistory | undefined): number {
  if (!h) return 2 + Math.random() * 0.5          // never attempted
  const accuracy = h.correct / h.total
  if (!h.lastCorrect) return 1 + (1 - accuracy)   // last attempt wrong, worse accuracy = higher
  return -(accuracy)                               // last attempt correct, better accuracy = further back
}

function sortedByPriority(qs: QuestionData[], hm: Map<string, QuestionHistory>): QuestionData[] {
  return [...qs].sort((a, b) => priorityScore(hm.get(b.id)) - priorityScore(hm.get(a.id)))
}

function shuffleAnswers(qs: QuestionData[]): QuestionData[] {
  return qs.map((q) => {
    const answers = [...q.answers]
    for (let i = answers.length - 1; i > 0; i--) {
      const j = Math.floor(Math.random() * (i + 1));
      [answers[i], answers[j]] = [answers[j], answers[i]]
    }
    return { ...q, answers }
  })
}

export default function QuestionDetail({ spaceId, token, onUnauthorized }: QuestionDetailProps) {
  const [questions, setQuestions] = useState<QuestionData[]>([])
  const [index, setIndex] = useState(0)
  const [selected, setSelected] = useState<Set<string>>(new Set())
  const [revealed, setRevealed] = useState(false)
  const [loading, setLoading] = useState(true)
  const [submitting, setSubmitting] = useState(false)
  const [historyMap, setHistoryMap] = useState<Map<string, QuestionHistory>>(new Map())
  // keep raw (answer-shuffled) questions separate so we can re-sort on history change
  const rawQuestionsRef = useRef<QuestionData[]>([])

  const applyOrder = useCallback((hm: Map<string, QuestionHistory>) => {
    if (rawQuestionsRef.current.length === 0) return
    setQuestions(sortedByPriority(rawQuestionsRef.current, hm))
    setIndex(0)
    setSelected(new Set())
    setRevealed(false)
  }, [])

  const fetchAttempts = useCallback(async (): Promise<Map<string, QuestionHistory>> => {
    try {
      const res = await fetch(`${API_URL}/spaces/${spaceId}/my-attempts`, {
        headers: { Authorization: `Bearer ${token}` },
      })
      if (!res.ok) return new Map()
      const data = await res.json()
      const attempts: AttemptItem[] = Array.isArray(data.attempts) ? data.attempts : []
      return buildHistoryMap(attempts)
    } catch (_) {
      return new Map()
    }
  }, [spaceId, token])

  const fetchQuestions = useCallback(async () => {
    setLoading(true)
    try {
      const res = await fetch(`${API_URL}/spaces/${spaceId}/questions`, {
        headers: { Authorization: `Bearer ${token}` },
      })
      if (res.status === 401) { onUnauthorized?.(); return }
      if (!res.ok) return
      const data = await res.json()
      const qs: QuestionData[] = Array.isArray(data) ? data : []
      // shuffle answers once on load (order stays stable across re-sorts)
      rawQuestionsRef.current = shuffleAnswers(qs)
    } catch (_) {}
    finally { setLoading(false) }
  }, [spaceId, token])

  useEffect(() => {
    const init = async () => {
      await fetchQuestions()
      const hm = await fetchAttempts()
      setHistoryMap(hm)
      applyOrder(hm)
    }
    init()
  }, [fetchQuestions, fetchAttempts, applyOrder])

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
  const history = historyMap.get(q.id) ?? null

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

  const navDots = questions.map((qItem, i) => {
    const h = historyMap.get(qItem.id)
    let cls = 'qd-dot'
    if (h) cls += h.lastCorrect ? ' qd-dot-correct' : ' qd-dot-wrong'
    if (i === index) cls += ' qd-dot-active'
    return (
      <span
        key={qItem.id}
        className={cls}
        onClick={() => { setIndex(i); setSelected(new Set()); setRevealed(false) }}
        title={h ? `${h.correct}/${h.total} correct` : 'Not attempted'}
      />
    )
  })

  return (
    <div className="problem-detail">
      <div className="qd-nav-row">
        <span className="qd-counter">{index + 1} / {questions.length}</span>
        <div className="qd-nav-btns">
          <button className="secondary btn-sm" onClick={() => go(-1)} disabled={index === 0}>← Prev</button>
          <button className="secondary btn-sm" onClick={() => go(1)} disabled={index === questions.length - 1}>Next →</button>
        </div>
      </div>

      <div className="qd-dot-strip">{navDots}</div>

      <section className="problem-detail-section">
        <div style={{ display: 'flex', alignItems: 'center', gap: '0.5rem', flexWrap: 'wrap' }}>
          <span className="question-type-badge">{q.question_type.replace('_', ' ')}</span>
          {isMulti && <span className="qd-multi-hint">Select all that apply</span>}
          {history && (
            <span className="qd-history-badge">
              {history.correct}/{history.total} correct
            </span>
          )}
        </div>
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
              <button
                onClick={async () => {
                  setSubmitting(true)
                  try {
                    await fetch(`${API_URL}/questions/${q.id}/attempt`, {
                      method: 'POST',
                      headers: { Authorization: `Bearer ${token}`, 'Content-Type': 'application/json' },
                      body: JSON.stringify({ selected_answer_ids: [...selected] }),
                    })
                    // refresh history and re-sort remaining questions
                    const hm = await fetchAttempts()
                    setHistoryMap(hm)
                    // re-sort questions after the current index so the already-seen ones aren't jumped
                    setQuestions((prev) => {
                      const seen = prev.slice(0, index + 1)
                      const remaining = sortedByPriority(prev.slice(index + 1), hm)
                      return [...seen, ...remaining]
                    })
                  } catch (_) {}
                  finally { setSubmitting(false) }
                  setRevealed(true)
                }}
                disabled={selected.size === 0 || submitting}
              >
                {submitting ? 'Checking…' : 'Check answer'}
              </button>
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
