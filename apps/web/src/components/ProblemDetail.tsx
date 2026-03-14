import { useCallback, useEffect, useState } from 'react'
import { API_URL } from '../config'

interface ProblemStep {
  id: string
  body: string
  position?: number
}

interface ProblemData {
  id: string
  question: string
  solution: string
  steps: ProblemStep[]
}

interface ProblemDetailProps {
  spaceItemId: string
  token: string
  onUnauthorized?: () => void
}

export default function ProblemDetail({ spaceItemId, token, onUnauthorized }: ProblemDetailProps) {
  const [problem, setProblem] = useState<ProblemData | null>(null)
  const [loading, setLoading] = useState(true)

  const fetchProblem = useCallback(async () => {
    setLoading(true)
    try {
      const res = await fetch(`${API_URL}/space-items/${spaceItemId}/problems`, {
        headers: { Authorization: `Bearer ${token}` },
      })
      if (res.status === 401) { onUnauthorized?.(); return }
      if (!res.ok) return
      const data = await res.json()
      setProblem(Array.isArray(data) && data.length > 0 ? data[0] : null)
    } catch (_) {}
    finally { setLoading(false) }
  }, [spaceItemId, token])

  useEffect(() => { fetchProblem() }, [fetchProblem])

  if (loading) return <div className="problem-detail-empty">Loading…</div>
  if (!problem) return <div className="problem-detail-empty">No problem data yet.</div>

  return (
    <div className="problem-detail">
      <section className="problem-detail-section">
        <h4 className="problem-detail-label">Question</h4>
        <p className="problem-detail-body">{problem.question}</p>
      </section>

      {problem.steps && problem.steps.length > 0 && (
        <section className="problem-detail-section">
          <h4 className="problem-detail-label">Steps</h4>
          <ol className="problem-steps-list">
            {problem.steps.map((step) => (
              <li key={step.id} className="problem-step-item">
                <span className="problem-step-body">{step.body}</span>
              </li>
            ))}
          </ol>
        </section>
      )}

      {problem.solution && (
        <section className="problem-detail-section">
          <h4 className="problem-detail-label">Solution</h4>
          <p className="problem-detail-body">{problem.solution}</p>
        </section>
      )}
    </div>
  )
}
