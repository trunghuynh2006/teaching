import TeacherContentStudio from '../components/TeacherContentStudio'

interface LandingProps {
  activeItem?: string
  token?: string
  onUnauthorized?: () => void
}

export function LearnerLanding({ activeItem }: LandingProps) {
  return (
    <section className="panel">
      <h2>Learner Home</h2>
      <p>Track your learning streak, upcoming assignments, and class milestones.</p>
      <div className="cards-grid">
        <article className="card glow">Current Focus: Algebra Module 3</article>
        <article className="card">Upcoming Quiz: Friday</article>
        <article className="card">Completion Rate: 78%</article>
      </div>
      <small>Selected menu: {activeItem}</small>
    </section>
  )
}

export function TeacherLanding({ activeItem, token, onUnauthorized }: LandingProps) {
  return (
    <section className="panel">
      <h2>Teacher Workspace</h2>
      <p>Manage classes, review submissions, and publish engaging lesson plans.</p>
      {activeItem === 'Content Studio' ? (
        <TeacherContentStudio token={token!} onUnauthorized={onUnauthorized!} />
      ) : (
        <div className="cards-grid">
          <article className="card glow">Pending Grading: 14 submissions</article>
          <article className="card">Live Class: Room 2B at 10:00</article>
          <article className="card">Content Drafts: 3</article>
        </div>
      )}
      <small>Selected menu: {activeItem}</small>
    </section>
  )
}

export function AdminLanding({ activeItem }: LandingProps) {
  return (
    <section className="panel">
      <h2>Admin Control Center</h2>
      <p>Oversee users, monitor platform performance, and enforce policy.</p>
      <div className="cards-grid">
        <article className="card glow">Total Users: 128</article>
        <article className="card">Weekly Active: 91</article>
        <article className="card">Incident Queue: 0 critical</article>
      </div>
      <small>Selected menu: {activeItem}</small>
    </section>
  )
}

export function ParentLanding({ activeItem }: LandingProps) {
  return (
    <section className="panel">
      <h2>Parent Snapshot</h2>
      <p>Stay informed on your child's progress, attendance, and teacher feedback.</p>
      <div className="cards-grid">
        <article className="card glow">Attendance: 96%</article>
        <article className="card">Latest Feedback: Great participation</article>
        <article className="card">Homework Completion: 9/10</article>
      </div>
      <small>Selected menu: {activeItem}</small>
    </section>
  )
}
