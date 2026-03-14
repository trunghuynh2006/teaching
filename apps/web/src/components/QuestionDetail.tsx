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
  spaceItemId: string
  token: string
  onUnauthorized?: () => void
}

export default function QuestionDetail({ spaceItemId, token, onUnauthorized }: QuestionDetailProps) {
  const [question, setQuestion] = useState<QuestionData | null>(null)
  const [loading, setLoading] = useState(true)

  const fetchQuestion = useCallback(async () => {
    setLoading(true)
    try {
      const res = await fetch(`${API_URL}/space-items/${spaceItemId}/questions`, {
        headers: { Authorization: `Bearer ${token}` },
      })
      if (res.status === 401) { onUnauthorized?.(); return }
      if (!res.ok) return
      const data = await res.json()
      setQuestion(Array.isArray(data) && data.length > 0 ? data[0] : null)
    } catch (_) {}
    finally { setLoading(false) }
  }, [spaceItemId, token])

  useEffect(() => { fetchQuestion() }, [fetchQuestion])

  if (loading) return <div className="problem-detail-empty">Loading…</div>
  if (!question) return <div className="problem-detail-empty">No question data yet.</div>

  return (
    <div className="problem-detail">
      <section className="problem-detail-section">
        <span className="question-type-badge">{question.question_type.replace('_', ' ')}</span>
        <h4 className="problem-detail-label" style={{ marginTop: '0.75rem' }}>Question</h4>
        <p className="problem-detail-body">{question.body}</p>
      </section>

      {question.answers && question.answers.length > 0 && (
        <section className="problem-detail-section">
          <h4 className="problem-detail-label">Answers</h4>
          <ul className="question-answers-list">
            {question.answers.map((ans) => (
              <li key={ans.id} className={`question-answer-item${ans.is_correct ? ' correct' : ''}`}>
                <span className="question-answer-marker">{ans.is_correct ? '✓' : '○'}</span>
                <span className="question-answer-text">{ans.text}</span>
              </li>
            ))}
          </ul>
        </section>
      )}
    </div>
  )
}
