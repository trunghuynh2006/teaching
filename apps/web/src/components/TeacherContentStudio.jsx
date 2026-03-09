import { Navigate, Route, Routes } from 'react-router-dom'
import TeacherSkillManager from './TeacherSkillManager'

export default function TeacherContentStudio({ token }) {
  return (
    <Routes>
      <Route index element={<Navigate to="skills" replace />} />
      <Route path="skills" element={<TeacherSkillManager token={token} mode="list" />} />
      <Route path="create" element={<TeacherSkillManager token={token} mode="form" />} />
      <Route path="*" element={<Navigate to="skills" replace />} />
    </Routes>
  )
}
