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
            <div key={item.path}>
              <button
                className={`nav-item ${isActive ? 'active' : ''}`}
                style={{ animationDelay: `${idx * 70}ms` }}
                onClick={() => onNavigate(item.path)}
              >
                {item.label}
              </button>
              {isActive &&
                item.children?.map((child) => {
                  const isChildActive =
                    activePath === child.path ||
                    activePath.startsWith(`${child.path}/`)
                  return (
                    <button
                      key={child.path}
                      className={`nav-item nav-child ${isChildActive ? 'active' : ''}`}
                      onClick={() => onNavigate(child.path)}
                    >
                      {child.label}
                    </button>
                  )
                })}
            </div>
          )
        })}
      </nav>
    </aside>
  )
}
