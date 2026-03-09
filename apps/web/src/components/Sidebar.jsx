export default function Sidebar({ role, menuItems, activePath, onNavigate }) {
  return (
    <aside className="sidebar">
      <div className="brand">Study Platform</div>
      <div className="role-badge">{role?.toUpperCase()}</div>
      <nav>
        {menuItems.map((item, idx) => {
          const isActive =
            activePath === item.path || activePath.startsWith(`${item.path}/`)

          return (
            <button
              key={item.path}
              className={`nav-item ${isActive ? 'active' : ''}`}
              style={{ animationDelay: `${idx * 70}ms` }}
              onClick={() => onNavigate(item.path)}
            >
              {item.label}
            </button>
          )
        })}
      </nav>
    </aside>
  )
}
