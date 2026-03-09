import { NavLink, Navigate, Route, Routes } from 'react-router-dom'
import TeacherSkillManager from './TeacherSkillManager'

export default function TeacherContentStudio({ token }) {
  return (
    <section className="content-studio-shell">
      <aside className="content-studio-submenu">
        <NavLink
          to="skills"
          className={({ isActive }) => `studio-link ${isActive ? 'active' : ''}`}
        >
          Skill Library
        </NavLink>
        <NavLink
          to="create"
          className={({ isActive }) => `studio-link ${isActive ? 'active' : ''}`}
        >
          Skill Form
        </NavLink>
      </aside>

      <div className="content-studio-panel">
        <Routes>
          <Route index element={<Navigate to="skills" replace />} />
          <Route path="skills" element={<TeacherSkillManager token={token} mode="list" />} />
          <Route path="create" element={<TeacherSkillManager token={token} mode="form" />} />
          <Route path="*" element={<Navigate to="skills" replace />} />
        </Routes>
      </div>
    </section>
  )
}
