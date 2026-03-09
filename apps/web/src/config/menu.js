export const MENU_BY_ROLE = {
  learner: [
    { label: 'My Courses', path: '/learner/courses' },
    { label: 'Assignments', path: '/learner/assignments' },
    { label: 'Progress', path: '/learner/progress' }
  ],
  teacher: [
    { label: 'My Classes', path: '/teacher/classes' },
    { label: 'Gradebook', path: '/teacher/gradebook' },
    {
      label: 'Content Studio',
      path: '/teacher/content-studio',
      nested: true,
      children: [
        { label: 'Skill Library', path: '/teacher/content-studio/skills' }
      ]
    }
  ],
  admin: [
    { label: 'User Management', path: '/admin/user-management' },
    { label: 'System Health', path: '/admin/system-health' },
    { label: 'Reports', path: '/admin/reports' }
  ],
  parent: [
    { label: 'Child Overview', path: '/parent/child-overview' },
    { label: 'Attendance', path: '/parent/attendance' },
    { label: 'Teacher Notes', path: '/parent/teacher-notes' }
  ]
}
