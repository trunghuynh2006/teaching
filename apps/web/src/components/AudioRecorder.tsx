import { useCallback, useEffect, useRef, useState } from 'react'
import { API_URL } from '../config'

type RecordingState = 'idle' | 'recording' | 'stopped'
type UploadStatus = 'idle' | 'uploading' | 'done' | 'error'

interface AudioRecorderProps {
  token: string
  onUnauthorized: () => void
}

export default function AudioRecorder({ token, onUnauthorized }: AudioRecorderProps) {
  const [state, setState] = useState<RecordingState>('idle')
  const [duration, setDuration] = useState(0)
  const [audioUrl, setAudioUrl] = useState<string | null>(null)
  const [uploadStatus, setUploadStatus] = useState<UploadStatus>('idle')
  const [uploadResult, setUploadResult] = useState<string | null>(null)

  const mediaRecorderRef = useRef<MediaRecorder | null>(null)
  const streamRef = useRef<MediaStream | null>(null)
  const analyserRef = useRef<AnalyserNode | null>(null)
  const canvasRef = useRef<HTMLCanvasElement>(null)
  const animFrameRef = useRef<number>(0)
  const timerRef = useRef<ReturnType<typeof setInterval> | null>(null)
  const chunksRef = useRef<Blob[]>([])

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

  const stopRecording = useCallback(() => {
    cancelAnimationFrame(animFrameRef.current)
    if (timerRef.current) clearInterval(timerRef.current)
    mediaRecorderRef.current?.stop()
    streamRef.current?.getTracks().forEach((t) => t.stop())
    setState('stopped')
  }, [])

  const startRecording = useCallback(async () => {
    // Clean up previous session
    cancelAnimationFrame(animFrameRef.current)
    if (timerRef.current) clearInterval(timerRef.current)
    streamRef.current?.getTracks().forEach((t) => t.stop())
    if (audioUrl) URL.revokeObjectURL(audioUrl)

    setAudioUrl(null)
    setUploadStatus('idle')
    setUploadResult(null)
    setDuration(0)
    chunksRef.current = []

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
        if (e.data.size > 0) chunksRef.current.push(e.data)
      }
      recorder.onstop = () => {
        const blob = new Blob(chunksRef.current, { type: 'audio/webm' })
        setAudioUrl(URL.createObjectURL(blob))
      }

      recorder.start()
      mediaRecorderRef.current = recorder
      setState('recording')

      timerRef.current = setInterval(() => setDuration((d) => d + 1), 1000)
      drawWaveform()
    } catch {
      alert('Could not access microphone. Please allow microphone permission and try again.')
    }
  }, [audioUrl, drawWaveform])

  const uploadRecording = useCallback(async () => {
    if (!chunksRef.current.length) return
    const blob = new Blob(chunksRef.current, { type: 'audio/webm' })
    const form = new FormData()
    form.append('audio', blob, 'recording.webm')

    setUploadStatus('uploading')
    try {
      const res = await fetch(`${API_URL}/recordings`, {
        method: 'POST',
        headers: { Authorization: `Bearer ${token}` },
        body: form,
      })
      if (res.status === 401) {
        onUnauthorized()
        return
      }
      const data = await res.json()
      if (!res.ok) {
        setUploadStatus('error')
        setUploadResult(data.detail || 'Upload failed')
        return
      }
      setUploadStatus('done')
      setUploadResult(`Saved: ${data.filename} (${formatBytes(data.size)})`)
    } catch {
      setUploadStatus('error')
      setUploadResult('Network error — check your connection and try again.')
    }
  }, [token, onUnauthorized])

  useEffect(() => {
    return () => {
      cancelAnimationFrame(animFrameRef.current)
      if (timerRef.current) clearInterval(timerRef.current)
      streamRef.current?.getTracks().forEach((t) => t.stop())
    }
  }, [])

  return (
    <div className="audio-recorder">
      <div className="recorder-canvas-wrap">
        <canvas ref={canvasRef} width={520} height={88} className="recorder-canvas" />
        {state === 'idle' && <p className="recorder-hint">Press record to start</p>}
        {state === 'recording' && (
          <span className="recorder-timer">{formatTime(duration)}</span>
        )}
      </div>

      <div className="recorder-controls">
        {state !== 'recording' ? (
          <button className="rec-btn" onClick={startRecording}>
            <span className="rec-dot" />
            {state === 'stopped' ? 'Re-record' : 'Record'}
          </button>
        ) : (
          <button className="rec-btn rec-btn--stop" onClick={stopRecording}>
            <span className="rec-square" />
            Stop
          </button>
        )}
      </div>

      {audioUrl && state === 'stopped' && (
        <div className="recorder-playback">
          <audio src={audioUrl} controls />
          <div className="recorder-upload-row">
            <button onClick={uploadRecording} disabled={uploadStatus === 'uploading'}>
              {uploadStatus === 'uploading' ? 'Uploading…' : 'Upload Recording'}
            </button>
          </div>
          {uploadStatus === 'done' && <p className="notice">{uploadResult}</p>}
          {uploadStatus === 'error' && <p className="error">{uploadResult}</p>}
        </div>
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
