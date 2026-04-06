export interface MenuItem {
  label: string
  path: string
  icon: string
}

export interface Section {
  label: string
  path: string        // prefix matched against location.pathname
  defaultPath: string // where to navigate when entering this section
}

export type Role = 'learner' | 'teacher' | 'admin' | 'parent'

// Top-level teacher sections shown in the topbar section switcher
export const TEACHER_SECTIONS: Section[] = [
  { label: 'My Classes',     path: '/teacher/classes',        defaultPath: '/teacher/classes' },
  { label: 'Gradebook',      path: '/teacher/gradebook',      defaultPath: '/teacher/gradebook' },
  { label: 'Content Studio', path: '/teacher/content-studio', defaultPath: '/teacher/content-studio/skills' },
]

// Context-based sidebar items per section (keyed by section.path)
export const SIDEBAR_BY_SECTION: Record<string, MenuItem[]> = {
  '/teacher/content-studio': [
    { label: 'Skill Library',  path: '/teacher/content-studio/skills',         icon: '📚' },
    { label: 'Folders',        path: '/teacher/content-studio/folders',        icon: '📁' },
    { label: 'Domains',        path: '/teacher/content-studio/domains',        icon: '🌐' },
    { label: 'Voice Recorder', path: '/teacher/content-studio/recorder',       icon: '🎙️' },
    { label: 'Audio Records',  path: '/teacher/content-studio/audio-records',  icon: '🔊' },
  ],
  '/teacher/classes':   [],
  '/teacher/gradebook': [],
}

// Sidebar items for non-teacher roles
export const MENU_BY_ROLE: Record<Role, MenuItem[]> = {
  learner: [],
  teacher: [],
  admin: [
    { label: 'User Management', path: '/admin/user-management', icon: '👥' },
    { label: 'System Health',   path: '/admin/system-health',   icon: '💚' },
    { label: 'Reports',         path: '/admin/reports',         icon: '📊' },
  ],
  parent: [
    { label: 'Child Overview', path: '/parent/child-overview', icon: '👶' },
    { label: 'Attendance',     path: '/parent/attendance',     icon: '📅' },
    { label: 'Teacher Notes',  path: '/parent/teacher-notes',  icon: '📋' },
  ],
}
