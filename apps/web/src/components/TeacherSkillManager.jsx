import { useCallback, useEffect, useMemo, useState } from 'react'
import { API_URL } from '../config'
import { SkillInput } from '../models/sharedModelsPackages/core'

const DEFAULT_FORM = {
  title: '',
  description: '',
  difficulty: 'beginner',
  tags: ''
}

function parseTags(rawTags) {
  return rawTags
    .split(',')
    .map((tag) => tag.trim())
    .filter((tag) => tag.length > 0)
}

function toSkillInputPayload(form) {
  return new SkillInput({
    title: form.title.trim(),
    description: form.description.trim(),
    difficulty: form.difficulty,
    tags: parseTags(form.tags)
  }).toJSON()
}

function toFormState(skill) {
  return {
    title: skill.title ?? '',
    description: skill.description ?? '',
    difficulty: skill.difficulty ?? 'beginner',
    tags: Array.isArray(skill.tags) ? skill.tags.join(', ') : ''
  }
}

function formatDate(dateTime) {
  if (!dateTime) {
    return '-'
  }

  const parsed = new Date(dateTime)
  if (Number.isNaN(parsed.getTime())) {
    return dateTime
  }

  return parsed.toLocaleString()
}

async function parseError(response) {
  try {
    const payload = await response.json()
    if (payload?.detail) {
      return payload.detail
    }
  } catch (_) {
    // Ignore JSON parse errors and fallback to status text below.
  }

  return response.statusText || 'Request failed'
}

export default function TeacherSkillManager({ token }) {
  const [skills, setSkills] = useState([])
  const [form, setForm] = useState(DEFAULT_FORM)
  const [editingId, setEditingId] = useState('')
  const [loading, setLoading] = useState(false)
  const [saving, setSaving] = useState(false)
  const [error, setError] = useState('')
  const [notice, setNotice] = useState('')

  const fetchSkills = useCallback(async () => {
    setLoading(true)
    setError('')
    try {
      const response = await fetch(`${API_URL}/skills`, {
        headers: { Authorization: `Bearer ${token}` }
      })
      if (!response.ok) {
        throw new Error(await parseError(response))
      }

      const payload = await response.json()
      setSkills(Array.isArray(payload) ? payload : [])
    } catch (err) {
      setError(err.message || 'Failed to load skills')
    } finally {
      setLoading(false)
    }
  }, [token])

  useEffect(() => {
    fetchSkills()
  }, [fetchSkills])

  const isEditing = useMemo(() => editingId.length > 0, [editingId])

  const resetForm = () => {
    setForm(DEFAULT_FORM)
    setEditingId('')
  }

  const handleSubmit = async (event) => {
    event.preventDefault()
    setError('')
    setNotice('')

    const payload = toSkillInputPayload(form)
    if (!SkillInput.validate(payload)) {
      setError('Invalid skill payload. Check form values and try again.')
      return
    }

    setSaving(true)
    try {
      const response = await fetch(
        isEditing ? `${API_URL}/skills/${editingId}` : `${API_URL}/skills`,
        {
          method: isEditing ? 'PUT' : 'POST',
          headers: {
            'Content-Type': 'application/json',
            Authorization: `Bearer ${token}`
          },
          body: JSON.stringify(payload)
        }
      )

      if (!response.ok) {
        throw new Error(await parseError(response))
      }

      setNotice(isEditing ? 'Skill updated' : 'Skill created')
      resetForm()
      await fetchSkills()
    } catch (err) {
      setError(err.message || 'Failed to save skill')
    } finally {
      setSaving(false)
    }
  }

  const handleEdit = (skill) => {
    setError('')
    setNotice('')
    setEditingId(skill.id)
    setForm(toFormState(skill))
  }

  const handleDelete = async (skill) => {
    if (!window.confirm(`Delete skill "${skill.title}"?`)) {
      return
    }

    setError('')
    setNotice('')
    try {
      const response = await fetch(`${API_URL}/skills/${skill.id}`, {
        method: 'DELETE',
        headers: { Authorization: `Bearer ${token}` }
      })
      if (!response.ok) {
        throw new Error(await parseError(response))
      }

      if (editingId === skill.id) {
        resetForm()
      }
      setNotice('Skill deleted')
      await fetchSkills()
    } catch (err) {
      setError(err.message || 'Failed to delete skill')
    }
  }

  const handlePublish = async (skill) => {
    setError('')
    setNotice('')
    try {
      const response = await fetch(`${API_URL}/skills/${skill.id}/publish`, {
        method: 'POST',
        headers: { Authorization: `Bearer ${token}` }
      })
      if (!response.ok) {
        throw new Error(await parseError(response))
      }

      setNotice('Skill published')
      await fetchSkills()
    } catch (err) {
      setError(err.message || 'Failed to publish skill')
    }
  }

  return (
    <section className="skill-studio">
      <div className="skill-studio-header">
        <h3>Skill Studio</h3>
        <button type="button" className="secondary" onClick={fetchSkills} disabled={loading}>
          {loading ? 'Refreshing...' : 'Refresh'}
        </button>
      </div>

      <form className="skill-form" onSubmit={handleSubmit}>
        <label>
          Title
          <input
            value={form.title}
            onChange={(event) => setForm((prev) => ({ ...prev, title: event.target.value }))}
            placeholder="Linear Equations"
            required
          />
        </label>

        <label>
          Description
          <input
            value={form.description}
            onChange={(event) => setForm((prev) => ({ ...prev, description: event.target.value }))}
            placeholder="Foundational equation-solving skill"
          />
        </label>

        <label>
          Difficulty
          <select
            value={form.difficulty}
            onChange={(event) => setForm((prev) => ({ ...prev, difficulty: event.target.value }))}
          >
            <option value="beginner">Beginner</option>
            <option value="intermediate">Intermediate</option>
            <option value="advanced">Advanced</option>
          </select>
        </label>

        <label>
          Tags (comma-separated)
          <input
            value={form.tags}
            onChange={(event) => setForm((prev) => ({ ...prev, tags: event.target.value }))}
            placeholder="algebra, equations, grade-8"
          />
        </label>

        <div className="skill-actions">
          <button type="submit" disabled={saving}>
            {saving ? 'Saving...' : isEditing ? 'Update Skill' : 'Create Skill'}
          </button>
          {isEditing && (
            <button type="button" className="secondary" onClick={resetForm}>
              Cancel Edit
            </button>
          )}
        </div>
      </form>

      {notice && <div className="notice">{notice}</div>}
      {error && <div className="error">{error}</div>}

      <div className="skill-list">
        {skills.length === 0 && !loading ? (
          <p>No skills yet. Create your first one above.</p>
        ) : (
          skills.map((skill) => (
            <article className="skill-item" key={skill.id}>
              <header>
                <h4>{skill.title}</h4>
                <span className={`pill ${skill.is_published ? 'live' : ''}`}>
                  {skill.is_published ? 'Published' : 'Draft'}
                </span>
              </header>
              {skill.description && <p>{skill.description}</p>}
              <div className="skill-meta">
                <span>Difficulty: {skill.difficulty || 'beginner'}</span>
                <span>Tags: {(skill.tags || []).join(', ') || '-'}</span>
                <span>Created by: {skill.created_by || '-'}</span>
                <span>Created: {formatDate(skill.created_time)}</span>
                <span>Updated by: {skill.updated_by || '-'}</span>
                <span>Updated: {formatDate(skill.updated_time)}</span>
              </div>
              <div className="skill-actions">
                {!skill.is_published && (
                  <button type="button" className="secondary" onClick={() => handlePublish(skill)}>
                    Publish
                  </button>
                )}
                <button type="button" onClick={() => handleEdit(skill)}>
                  Edit
                </button>
                <button type="button" className="danger" onClick={() => handleDelete(skill)}>
                  Delete
                </button>
              </div>
            </article>
          ))
        )}
      </div>
    </section>
  )
}
