import { Navigate, Route, Routes } from 'react-router-dom'
import AudioRecordList from './AudioRecordList'
import AudioRecorder from './AudioRecorder'
import DomainManager from './DomainManager'
import FolderManager from './FolderManager'
import TeacherSkillManager from './TeacherSkillManager'

interface TeacherContentStudioProps {
  token: string
  onUnauthorized: () => void
}

export default function TeacherContentStudio({ token, onUnauthorized }: TeacherContentStudioProps) {
  return (
    <Routes>
      <Route index element={<Navigate to="skills" replace />} />
      <Route path="skills" element={<TeacherSkillManager token={token} mode="list" onUnauthorized={onUnauthorized} />} />
      <Route path="create" element={<TeacherSkillManager token={token} mode="form" onUnauthorized={onUnauthorized} />} />
      <Route path="recorder" element={<AudioRecorder token={token} onUnauthorized={onUnauthorized} />} />
      <Route path="audio-records" element={<AudioRecordList token={token} onUnauthorized={onUnauthorized} />} />
      <Route path="folders" element={<FolderManager token={token} onUnauthorized={onUnauthorized} />} />
      <Route path="domains" element={<DomainManager token={token} onUnauthorized={onUnauthorized} />} />
      <Route path="*" element={<Navigate to="skills" replace />} />
    </Routes>
  )
}
