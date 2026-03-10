import { useCallback, useEffect, useRef, useState } from 'react'
import { API_URL } from '../config'

type RecordingState = 'idle' | 'recording' | 'finalizing' | 'done' | 'error'

interface AudioRecorderProps {
  token: string
  onUnauthorized: () => void
}

interface RecordingResult {
  filename: string
  size: number
}

export default function AudioRecorder({ token, onUnauthorized }: AudioRecorderProps) {
  const [state, setState] = useState<RecordingState>('idle')
  const [duration, setDuration] = useState(0)
  const [audioUrl, setAudioUrl] = useState<string | null>(null)
  const [result, setResult] = useState<RecordingResult | null>(null)
  const [errorMsg, setErrorMsg] = useState<string | null>(null)

  const mediaRecorderRef = useRef<MediaRecorder | null>(null)
  const streamRef = useRef<MediaStream | null>(null)
  const analyserRef = useRef<AnalyserNode | null>(null)
  const canvasRef = useRef<HTMLCanvasElement>(null)
  const animFrameRef = useRef<number>(0)
  const timerRef = useRef<ReturnType<typeof setInterval> | null>(null)
  // local chunks for playback
  const localChunksRef = useRef<Blob[]>([])
  // in-flight chunk upload promises
  const pendingUploadsRef = useRef<Promise<void>[]>([])
  const sessionIdRef = useRef<string | null>(null)
  const tokenRef = useRef(token)
  tokenRef.current = token

  const drawWaveform = useCallback(() => {
    const canvas = canvasRef.current
    const analyser = analyserRef.current
    if (!canvas || !analyser) return

    const ctx = canvas.getContext('2d')!
    const bufferLength = analyser.frequencyBinCount
    const dataArray = new Uint8Array(bufferLength)

    const draw = () => {
      animFrameRef.current = requestAnimationFrame(draw)
      analyser.getByteFrequencyData(dataArray)

      const W = canvas.width
      const H = canvas.height
      ctx.clearRect(0, 0, W, H)

      const barCount = 48
      const barW = W / barCount - 2

      for (let i = 0; i < barCount; i++) {
        const idx = Math.floor((i / barCount) * bufferLength)
        const val = dataArray[idx] / 255
        const barH = Math.max(4, val * H * 0.88)
        const x = i * (barW + 2)
        const y = (H - barH) / 2
        ctx.fillStyle = `rgba(14, 133, 118, ${0.45 + val * 0.55})`
        ctx.beginPath()
        ctx.roundRect(x, y, barW, barH, 3)
        ctx.fill()
      }
    }

    draw()
  }, [])

  const authHeaders = useCallback(
    () => ({ Authorization: `Bearer ${tokenRef.current}` }),
    []
  )

  const uploadChunk = useCallback(
    (sessionId: string, chunk: Blob): Promise<void> => {
      return fetch(`${API_URL}/recordings/sessions/${sessionId}/chunks`, {
        method: 'POST',
        headers: authHeaders(),
        body: chunk,
      }).then((res) => {
        if (res.status === 401) onUnauthorized()
      })
    },
    [authHeaders, onUnauthorized]
  )

  const stopRecording = useCallback(() => {
    cancelAnimationFrame(animFrameRef.current)
    if (timerRef.current) clearInterval(timerRef.current)
    mediaRecorderRef.current?.stop()
    streamRef.current?.getTracks().forEach((t) => t.stop())
  }, [])

  const startRecording = useCallback(async () => {
    // clean up previous
    cancelAnimationFrame(animFrameRef.current)
    if (timerRef.current) clearInterval(timerRef.current)
    streamRef.current?.getTracks().forEach((t) => t.stop())
    if (audioUrl) URL.revokeObjectURL(audioUrl)

    setAudioUrl(null)
    setResult(null)
    setErrorMsg(null)
    setDuration(0)
    localChunksRef.current = []
    pendingUploadsRef.current = []
    sessionIdRef.current = null

    // 1. Create session
    let sessionId: string
    try {
      const res = await fetch(`${API_URL}/recordings/sessions`, {
        method: 'POST',
        headers: authHeaders(),
      })
      if (res.status === 401) { onUnauthorized(); return }
      if (!res.ok) { setState('error'); setErrorMsg('Could not start session'); return }
      const data = await res.json()
      sessionId = data.session_id
      sessionIdRef.current = sessionId
    } catch {
      setState('error')
      setErrorMsg('Network error — could not create recording session')
      return
    }

    // 2. Mic + waveform
    try {
      const stream = await navigator.mediaDevices.getUserMedia({ audio: true })
      streamRef.current = stream

      const audioCtx = new AudioContext()
      const source = audioCtx.createMediaStreamSource(stream)
      const analyser = audioCtx.createAnalyser()
      analyser.fftSize = 128
      source.connect(analyser)
      analyserRef.current = analyser

      const recorder = new MediaRecorder(stream)

      recorder.ondataavailable = (e) => {
        if (e.data.size === 0) return
        localChunksRef.current.push(e.data)
        // upload chunk immediately
        pendingUploadsRef.current.push(uploadChunk(sessionId, e.data))
      }

      recorder.onstop = async () => {
        // build local playback URL
        const blob = new Blob(localChunksRef.current, { type: 'audio/webm' })
        setAudioUrl(URL.createObjectURL(blob))

        setState('finalizing')

        // wait for all in-flight chunk uploads
        try {
          await Promise.all(pendingUploadsRef.current)
        } catch {
          setState('error')
          setErrorMsg('Some chunks failed to upload')
          return
        }

        // finalize
        try {
          const res = await fetch(
            `${API_URL}/recordings/sessions/${sessionId}/finalize`,
            { method: 'POST', headers: authHeaders() }
          )
          if (res.status === 401) { onUnauthorized(); return }
          const data = await res.json()
          if (!res.ok) {
            setState('error')
            setErrorMsg(data.detail || 'Finalize failed')
            return
          }
          setResult({ filename: data.filename, size: data.size })
          setState('done')
        } catch {
          setState('error')
          setErrorMsg('Network error during finalize')
        }
      }

      // timeslice: emit a chunk every second while recording
      recorder.start(1000)
      mediaRecorderRef.current = recorder
      setState('recording')

      timerRef.current = setInterval(() => setDuration((d) => d + 1), 1000)
      drawWaveform()
    } catch {
      setState('error')
      setErrorMsg('Could not access microphone — please allow permission and try again')
    }
  }, [audioUrl, authHeaders, drawWaveform, onUnauthorized, uploadChunk])

  useEffect(() => {
    return () => {
      cancelAnimationFrame(animFrameRef.current)
      if (timerRef.current) clearInterval(timerRef.current)
      streamRef.current?.getTracks().forEach((t) => t.stop())
    }
  }, [])

  const canRecord = state === 'idle' || state === 'done' || state === 'error'
  const isRecording = state === 'recording'
  const isFinalizing = state === 'finalizing'

  return (
    <div className="audio-recorder">
      <div className="recorder-canvas-wrap">
        <canvas ref={canvasRef} width={520} height={88} className="recorder-canvas" />
        {state === 'idle' && <p className="recorder-hint">Press record to start</p>}
        {isRecording && <span className="recorder-timer">{formatTime(duration)}</span>}
        {isFinalizing && <p className="recorder-hint">Saving…</p>}
      </div>

      <div className="recorder-controls">
        {canRecord && (
          <button className="rec-btn" onClick={startRecording}>
            <span className="rec-dot" />
            {state === 'done' || state === 'error' ? 'Re-record' : 'Record'}
          </button>
        )}
        {isRecording && (
          <button className="rec-btn rec-btn--stop" onClick={stopRecording}>
            <span className="rec-square" />
            Stop
          </button>
        )}
        {isFinalizing && (
          <button className="rec-btn" disabled>
            <span className="rec-dot" />
            Saving…
          </button>
        )}
      </div>

      {audioUrl && (
        <div className="recorder-playback">
          <audio src={audioUrl} controls />
          {state === 'done' && result && (
            <p className="notice">Saved: {result.filename} ({formatBytes(result.size)})</p>
          )}
          {state === 'error' && errorMsg && <p className="error">{errorMsg}</p>}
        </div>
      )}

      {state === 'error' && !audioUrl && errorMsg && (
        <p className="error">{errorMsg}</p>
      )}
    </div>
  )
}

function formatTime(s: number) {
  return `${String(Math.floor(s / 60)).padStart(2, '0')}:${String(s % 60).padStart(2, '0')}`
}

function formatBytes(bytes: number) {
  if (bytes < 1024) return `${bytes} B`
  if (bytes < 1024 * 1024) return `${(bytes / 1024).toFixed(1)} KB`
  return `${(bytes / (1024 * 1024)).toFixed(1)} MB`
}
