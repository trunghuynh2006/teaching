const menuByRole = {
  learner: ['My Courses', 'Assignments', 'Progress'],
  teacher: ['My Classes', 'Gradebook', 'Content Studio'],
  admin: ['User Management', 'System Health', 'Reports'],
  parent: ['Child Overview', 'Attendance', 'Teacher Notes']
}

export default function Sidebar({ role, activeItem, onSelect }) {
  const menuItems = menuByRole[role] || []

  return (
    <aside className="sidebar">
      <div className="brand">Study Platform</div>
      <div className="role-badge">{role?.toUpperCase()}</div>
      <nav>
        {menuItems.map((item, idx) => (
          <button
            key={item}
            className={`nav-item ${activeItem === item ? 'active' : ''}`}
            style={{ animationDelay: `${idx * 70}ms` }}
            onClick={() => onSelect(item)}
          >
            {item}
          </button>
        ))}
      </nav>
    </aside>
  )
}
