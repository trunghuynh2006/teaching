import { useEffect, useState } from 'react'
import { useNavigate } from 'react-router-dom'
import { API_URL } from '../config'

interface LearnerHomeProps {
  token: string
  userName: string
  onUnauthorized: () => void
}

interface SpaceSummary {
  spaceId: string
  spaceName: string
  folderId: string
  folderName: string
  totalAttempts: number
  correctAttempts: number
  dueCards: number
  lastActivityAt: string | null
}

interface RecentAttempt {
  questionId: string
  spaceId: string
  spaceName: string
  isCorrect: boolean
  answeredAt: string
}

function greeting() {
  const h = new Date().getHours()
  if (h < 12) return 'Good morning'
  if (h < 18) return 'Good afternoon'
  return 'Good evening'
}

function timeAgo(iso: string): string {
  const diff = Date.now() - new Date(iso).getTime()
  const m = Math.floor(diff / 60000)
  if (m < 1) return 'just now'
  if (m < 60) return `${m}m ago`
  const h = Math.floor(m / 60)
  if (h < 24) return `${h}h ago`
  return `${Math.floor(h / 24)}d ago`
}

export default function LearnerHome({ token, userName, onUnauthorized }: LearnerHomeProps) {
  const navigate = useNavigate()
  const [summaries, setSummaries] = useState<SpaceSummary[]>([])
  const [recent, setRecent] = useState<RecentAttempt[]>([])
  const [loading, setLoading] = useState(true)

  useEffect(() => {
    const headers = { Authorization: `Bearer ${token}` }

    const run = async () => {
      setLoading(true)
      try {
        // 1. folders
        const fRes = await fetch(`${API_URL}/folders`, { headers })
        if (fRes.status === 401) { onUnauthorized(); return }
        if (!fRes.ok) return
        const folders: { id: string; name: string }[] = await fRes.json()

        // 2. spaces per folder — parallel
        const folderSpaces = await Promise.all(
          folders.map(async (f) => {
            const r = await fetch(`${API_URL}/folders/${f.id}/spaces`, { headers })
            if (!r.ok) return { folder: f, spaces: [] as { id: string; name: string }[] }
            const spaces: { id: string; name: string }[] = await r.json()
            return { folder: f, spaces }
          })
        )

        // 3. attempts + due cards per space — parallel
        const allSpaces = folderSpaces.flatMap(({ folder, spaces }) =>
          spaces.map((s) => ({ folder, space: s }))
        )

        const spaceData = await Promise.all(
          allSpaces.map(async ({ folder, space }) => {
            const [attRes, dueRes] = await Promise.all([
              fetch(`${API_URL}/spaces/${space.id}/my-attempts`, { headers }),
              fetch(`${API_URL}/spaces/${space.id}/flash-cards/due`, { headers }),
            ])
            const attData = attRes.ok ? await attRes.json() : { attempts: [] }
            const dueData = dueRes.ok ? await dueRes.json() : []
            const attempts: { is_correct: boolean; answered_at: string; question_id: string }[] =
              attData.attempts ?? []
            const dueCards: unknown[] = Array.isArray(dueData) ? dueData : (dueData.flash_cards ?? [])

            const lastActivityAt =
              attempts.length > 0 ? attempts[0].answered_at : null

            return {
              spaceId: space.id,
              spaceName: space.name,
              folderId: folder.id,
              folderName: folder.name,
              totalAttempts: attempts.length,
              correctAttempts: attempts.filter((a) => a.is_correct).length,
              dueCards: dueCards.length,
              lastActivityAt,
              // keep raw attempts for recent list
              _attempts: attempts.slice(0, 10).map((a) => ({
                questionId: a.question_id,
                spaceId: space.id,
                spaceName: space.name,
                isCorrect: a.is_correct,
                answeredAt: a.answered_at,
              })),
            }
          })
        )

        // only show spaces with any activity or due cards
        const active = spaceData
          .filter((s) => s.totalAttempts > 0 || s.dueCards > 0)
          .sort((a, b) => {
            // sort by last activity, most recent first
            if (!a.lastActivityAt && !b.lastActivityAt) return 0
            if (!a.lastActivityAt) return 1
            if (!b.lastActivityAt) return -1
            return new Date(b.lastActivityAt).getTime() - new Date(a.lastActivityAt).getTime()
          })

        setSummaries(active)

        // collect recent attempts across spaces, sort by time, take top 8
        const allRecent = spaceData
          .flatMap((s) => s._attempts)
          .sort((a, b) => new Date(b.answeredAt).getTime() - new Date(a.answeredAt).getTime())
          .slice(0, 8)
        setRecent(allRecent)
      } catch (_) {}
      finally { setLoading(false) }
    }

    run()
  }, [token, onUnauthorized])

  const totalAttempts = summaries.reduce((n, s) => n + s.totalAttempts, 0)
  const totalCorrect = summaries.reduce((n, s) => n + s.correctAttempts, 0)
  const totalDue = summaries.reduce((n, s) => n + s.dueCards, 0)
  const accuracy = totalAttempts > 0 ? Math.round((totalCorrect / totalAttempts) * 100) : null

  const firstName = userName.split(' ')[0]

  return (
    <div className="learner-home">
      <p className="learner-home-greeting">{greeting()}, {firstName}.</p>

      {loading ? (
        <p className="learner-home-loading">Loading your progress…</p>
      ) : (
        <>
          {totalAttempts > 0 && (
            <p className="learner-home-summary">
              You've answered <strong>{totalAttempts}</strong> question{totalAttempts !== 1 ? 's' : ''} across all spaces
              {accuracy !== null && <>, with a <strong>{accuracy}%</strong> accuracy rate</>}.
              {totalDue > 0 && <> <strong>{totalDue}</strong> flash card{totalDue !== 1 ? 's' : ''} due for review.</>}
            </p>
          )}
          {totalAttempts === 0 && totalDue === 0 && (
            <p className="learner-home-summary">
              Nothing studied yet.{' '}
              <button className="learner-home-link" onClick={() => navigate('/learner/folders')}>
                Open a folder to get started.
              </button>
            </p>
          )}

          {summaries.length > 0 && (
            <section className="learner-home-section">
              <h3 className="learner-home-section-title">Your study areas</h3>
              <ul className="learner-home-space-list">
                {summaries.map((s) => {
                  const acc = s.totalAttempts > 0
                    ? Math.round((s.correctAttempts / s.totalAttempts) * 100)
                    : null
                  return (
                    <li key={s.spaceId} className="learner-home-space-item">
                      <div className="learner-home-space-header">
                        <span className="learner-home-space-name">{s.spaceName}</span>
                        <span className="learner-home-space-folder">{s.folderName}</span>
                      </div>
                      <div className="learner-home-space-meta">
                        {s.totalAttempts > 0 && (
                          <span>{s.totalAttempts} attempts · {acc}% correct</span>
                        )}
                        {s.dueCards > 0 && (
                          <span className="learner-home-due">{s.dueCards} card{s.dueCards !== 1 ? 's' : ''} due</span>
                        )}
                        {s.lastActivityAt && (
                          <span className="learner-home-time">{timeAgo(s.lastActivityAt)}</span>
                        )}
                      </div>
                    </li>
                  )
                })}
              </ul>
            </section>
          )}

          {recent.length > 0 && (
            <section className="learner-home-section">
              <h3 className="learner-home-section-title">Recent activity</h3>
              <ul className="learner-home-recent-list">
                {recent.map((a, i) => (
                  <li key={i} className="learner-home-recent-item">
                    <span className={`learner-home-recent-icon ${a.isCorrect ? 'correct' : 'wrong'}`}>
                      {a.isCorrect ? '✓' : '✗'}
                    </span>
                    <span className="learner-home-recent-space">{a.spaceName}</span>
                    <span className="learner-home-recent-time">{timeAgo(a.answeredAt)}</span>
                  </li>
                ))}
              </ul>
            </section>
          )}
        </>
      )}
    </div>
  )
}
