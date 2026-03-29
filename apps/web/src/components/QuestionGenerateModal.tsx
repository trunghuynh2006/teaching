import { useEffect, useState } from 'react'
import { API_URL } from '../config'
import type { SourceItem } from './KnowledgeManager'

interface GeneratedAnswer {
  id: string
  text: string
  is_correct: boolean
}

interface GeneratedQuestion {
  id: string
  body: string
  answers: GeneratedAnswer[]
}

interface QuestionGenerateModalProps {
  spaceId: string
  folderId: string
  token: string
  onUnauthorized?: () => void
  onDone: () => void
  onClose: () => void
}

async function parseError(res: Response): Promise<string> {
  try {
    const p = await res.json()
    if (p?.detail) return p.detail
  } catch (_) {}
  return res.statusText || 'Request failed'
}

export default function QuestionGenerateModal({ spaceId, folderId, token, onUnauthorized, onDone, onClose }: QuestionGenerateModalProps) {
  const [sources, setSources] = useState<SourceItem[]>([])
  const [loadingSource, setLoadingSource] = useState(true)
  const [selectedSourceId, setSelectedSourceId] = useState('')
  const [generating, setGenerating] = useState(false)
  const [questions, setQuestions] = useState<GeneratedQuestion[]>([])
  const [error, setError] = useState('')

  const headers = { Authorization: `Bearer ${token}` }

  useEffect(() => {
    const load = async () => {
      try {
        const res = await fetch(`${API_URL}/folders/${folderId}/sources`, { headers })
        if (res.status === 401) { onUnauthorized?.(); return }
        if (!res.ok) return
        const data: SourceItem[] = await res.json()
        setSources(Array.isArray(data) ? data : [])
      } finally {
        setLoadingSource(false)
      }
    }
    load()
  }, [folderId, token])

  const handleGenerate = async () => {
    if (!selectedSourceId) return
    setGenerating(true)
    setError('')
    try {
      const res = await fetch(`${API_URL}/spaces/${spaceId}/generate-questions`, {
        method: 'POST',
        headers: { ...headers, 'Content-Type': 'application/json' },
        body: JSON.stringify({ source_id: selectedSourceId }),
      })
      if (res.status === 401) { onUnauthorized?.(); return }
      if (!res.ok) throw new Error(await parseError(res))
      const data = await res.json()
      setQuestions(data.questions ?? [])
    } catch (err) {
      setError((err as Error).message || 'Failed to generate questions')
    } finally {
      setGenerating(false)
    }
  }

  return (
    <div className="modal-overlay" onClick={(e) => { if (e.target === e.currentTarget) onClose() }}>
      <div className="modal-box anki-generate-modal">
        <div className="modal-header">
          <span>Generate Questions from Knowledge</span>
          <button className="modal-close" type="button" onClick={onClose}>✕</button>
        </div>
        <div className="modal-body">
          {error && <div className="error">{error}</div>}

          {questions.length === 0 ? (
            <>
              {loadingSource ? (
                <p>Loading sources…</p>
              ) : sources.length === 0 ? (
                <p className="anki-generate-empty">No knowledge sources available in this folder.</p>
              ) : (
                <>
                  <label className="modal-field">
                    Select a knowledge source
                    <select
                      value={selectedSourceId}
                      onChange={(e) => setSelectedSourceId(e.target.value)}
                    >
                      <option value="">— choose a source —</option>
                      {sources.map((s) => (
                        <option key={s.id} value={s.id}>
                          {s.title || s.content.slice(0, 60) + (s.content.length > 60 ? '…' : '')}
                        </option>
                      ))}
                    </select>
                  </label>
                  <div className="modal-actions">
                    <button
                      type="button"
                      onClick={handleGenerate}
                      disabled={generating || !selectedSourceId}
                    >
                      {generating ? 'Generating…' : 'Generate Questions'}
                    </button>
                    <button type="button" className="secondary" onClick={onClose}>Cancel</button>
                  </div>
                </>
              )}
            </>
          ) : (
            <>
              <p className="anki-generate-hint">{questions.length} question{questions.length !== 1 ? 's' : ''} generated and saved.</p>
              <div className="qgen-review-list">
                {questions.map((q, qi) => (
                  <div key={q.id} className="qgen-review-item">
                    <p className="qgen-review-body"><strong>Q{qi + 1}:</strong> {q.body}</p>
                    <ul className="qgen-review-answers">
                      {q.answers.map((a) => (
                        <li key={a.id} className={a.is_correct ? 'qgen-answer-correct' : ''}>
                          {a.is_correct ? '✓' : '○'} {a.text}
                        </li>
                      ))}
                    </ul>
                  </div>
                ))}
              </div>
              <div className="modal-actions">
                <button type="button" onClick={onDone}>Done</button>
              </div>
            </>
          )}
        </div>
      </div>
    </div>
  )
}
