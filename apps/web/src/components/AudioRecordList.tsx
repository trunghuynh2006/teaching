import { useEffect, useState } from 'react'
import { API_URL } from '../config'

interface AudioRecord {
  id: string
  user_id: string
  filename: string
  file_size: number
  transcript: string
  created_at: string
}

interface AudioRecordListProps {
  token: string
  onUnauthorized: () => void
}

export default function AudioRecordList({ token, onUnauthorized }: AudioRecordListProps) {
  const [records, setRecords] = useState<AudioRecord[]>([])
  const [loading, setLoading] = useState(true)
  const [error, setError] = useState<string | null>(null)

  useEffect(() => {
    fetch(`${API_URL}/audio-records`, {
      headers: { Authorization: `Bearer ${token}` },
    })
      .then((res) => {
        if (res.status === 401) { onUnauthorized(); return null }
        if (!res.ok) throw new Error(`Server error ${res.status}`)
        return res.json()
      })
      .then((data) => { if (data) setRecords(data) })
      .catch((err) => setError(err.message))
      .finally(() => setLoading(false))
  }, [token, onUnauthorized])

  if (loading) return <p className="ar-empty">Loading…</p>
  if (error) return <p className="error">{error}</p>

  return (
    <div className="ar-list">
      {records.length === 0 && (
        <p className="ar-empty">No recordings yet. Use the Voice Recorder to create one.</p>
      )}
      {records.map((rec) => (
        <article key={rec.id} className="ar-item">
          <header className="ar-item-header">
            <span className="ar-filename">{rec.filename}</span>
            <span className="pill">{formatBytes(rec.file_size)}</span>
          </header>
          <p className="ar-meta">
            <span>By {rec.user_id}</span>
            <span>{formatDate(rec.created_at)}</span>
          </p>
          {rec.transcript ? (
            <blockquote className="ar-transcript">{rec.transcript}</blockquote>
          ) : (
            <p className="ar-no-transcript">No transcript</p>
          )}
        </article>
      ))}
    </div>
  )
}

function formatBytes(bytes: number) {
  if (bytes < 1024) return `${bytes} B`
  if (bytes < 1024 * 1024) return `${(bytes / 1024).toFixed(1)} KB`
  return `${(bytes / (1024 * 1024)).toFixed(1)} MB`
}

function formatDate(iso: string) {
  if (!iso) return ''
  return new Date(iso).toLocaleString()
}
