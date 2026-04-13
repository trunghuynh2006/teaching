import { useCallback, useEffect, useState } from 'react'
import { API_URL } from '../config'

const API = API_URL

interface Domain {
  id: string
  name: string
  description: string
  parents: string[]
  children: string[]
  created_time?: string
}

interface DomainTreeNode extends Domain {
  childNodes: DomainTreeNode[]
}

interface Concept {
  id: string
  canonical_name: string
  level: string
  scope: string
  description: string
  tags: string[]
}

interface DomainManagerProps {
  token: string
  onUnauthorized: () => void
}

const LEVEL_COLOR: Record<string, string> = {
  foundation: '#2d8a4e',
  intermediate: '#c07a00',
  advanced: '#c0392b',
}

export default function DomainManager({ token, onUnauthorized }: DomainManagerProps) {
  const [domains, setDomains] = useState<Domain[]>([])
  const [loading, setLoading] = useState(true)
  const [error, setError] = useState('')

  // Modal state
  const [showForm, setShowForm] = useState(false)
  const [editDomain, setEditDomain] = useState<Domain | null>(null)
  const [formName, setFormName] = useState('')
  const [formDescription, setFormDescription] = useState('')
  const [formSaving, setFormSaving] = useState(false)
  const [formError, setFormError] = useState('')

  // Per-domain action state
  const [discovering, setDiscovering] = useState<Record<string, boolean>>({})
  const [generating, setGenerating] = useState<Record<string, boolean>>({})
  const [actionMsg, setActionMsg] = useState<Record<string, string>>({})

  // Per-domain concepts panel state
  const [expandedConcepts, setExpandedConcepts] = useState<Record<string, boolean>>({})
  const [domainConcepts, setDomainConcepts] = useState<Record<string, Concept[]>>({})
  const [loadingConcepts, setLoadingConcepts] = useState<Record<string, boolean>>({})

  const authHeaders = useCallback(
    () => ({ Authorization: `Bearer ${token}`, 'Content-Type': 'application/json' }),
    [token],
  )

  const fetchDomains = useCallback(async () => {
    setLoading(true)
    setError('')
    try {
      const res = await fetch(`${API}/domains`, { headers: authHeaders() })
      if (res.status === 401) { onUnauthorized(); return }
      if (!res.ok) throw new Error('Failed to load domains')
      const data = await res.json()
      setDomains(data.domains ?? [])
    } catch (e: unknown) {
      setError(e instanceof Error ? e.message : 'Unknown error')
    } finally {
      setLoading(false)
    }
  }, [authHeaders, onUnauthorized])

  useEffect(() => { fetchDomains() }, [fetchDomains])

  async function toggleConcepts(d: Domain) {
    const isOpen = expandedConcepts[d.id]
    setExpandedConcepts(prev => ({ ...prev, [d.id]: !isOpen }))
    // Load if opening and not yet loaded
    if (!isOpen && !domainConcepts[d.id]) {
      setLoadingConcepts(prev => ({ ...prev, [d.id]: true }))
      try {
        const res = await fetch(`${API}/concepts?domain=${encodeURIComponent(d.name)}`, { headers: authHeaders() })
        if (res.status === 401) { onUnauthorized(); return }
        const data = await res.json()
        setDomainConcepts(prev => ({ ...prev, [d.id]: Array.isArray(data) ? data : (data.concepts ?? []) }))
      } finally {
        setLoadingConcepts(prev => ({ ...prev, [d.id]: false }))
      }
    }
  }

  // Build tree: find root nodes (no parents) and attach children.
  function buildTree(domains: Domain[]): DomainTreeNode[] {
    const byName = new Map<string, DomainTreeNode>()
    for (const d of domains) {
      byName.set(d.name, { ...d, parents: d.parents ?? [], children: d.children ?? [], childNodes: [] })
    }
    const roots: DomainTreeNode[] = []
    for (const node of byName.values()) {
      if (node.parents.length === 0) {
        roots.push(node)
      } else {
        // When a node has multiple parents, only attach it to the most specific one —
        // the parent that is itself a child of another parent in the list.
        // This prevents a node appearing multiple times in the tree.
        const validParents = node.parents.map(n => byName.get(n)).filter(Boolean) as DomainTreeNode[]
        const bestParent = validParents.find(p =>
          p.parents.some(grandparent => node.parents.includes(grandparent))
        ) ?? validParents[0]

        if (bestParent) {
          bestParent.childNodes.push(node)
        } else {
          roots.push(node)
        }
      }
    }
    roots.sort((a, b) => a.name.localeCompare(b.name))
    return roots
  }

  function openCreate() {
    setEditDomain(null)
    setFormName('')
    setFormDescription('')
    setFormError('')
    setShowForm(true)
  }

  function openEdit(d: Domain) {
    setEditDomain(d)
    setFormName(d.name)
    setFormDescription(d.description)
    setFormError('')
    setShowForm(true)
  }

  async function saveDomain() {
    if (!formName.trim()) { setFormError('Name is required'); return }
    setFormSaving(true)
    setFormError('')
    try {
      const url = editDomain ? `${API}/domains/${editDomain.id}` : `${API}/domains`
      const method = editDomain ? 'PUT' : 'POST'
      const res = await fetch(url, {
        method,
        headers: authHeaders(),
        body: JSON.stringify({ name: formName.trim(), description: formDescription.trim() }),
      })
      if (res.status === 401) { onUnauthorized(); return }
      if (res.status === 409) { setFormError('Domain already exists'); return }
      if (!res.ok) { setFormError('Failed to save domain'); return }
      setShowForm(false)
      fetchDomains()
    } finally {
      setFormSaving(false)
    }
  }

  async function deleteDomain(d: Domain) {
    if (!confirm(`Delete domain "${d.name}"?`)) return
    const res = await fetch(`${API}/domains/${d.id}`, { method: 'DELETE', headers: authHeaders() })
    if (res.status === 401) { onUnauthorized(); return }
    fetchDomains()
  }

  async function discoverParents(d: Domain) {
    setDiscovering(prev => ({ ...prev, [d.id]: true }))
    setActionMsg(prev => ({ ...prev, [d.id]: '' }))
    try {
      const res = await fetch(`${API}/domains/${d.id}/discover-parents`, { method: 'POST', headers: authHeaders() })
      if (res.status === 401) { onUnauthorized(); return }
      const data = await res.json()
      const parents: string[] = data.parent_domains ?? []
      setActionMsg(prev => ({ ...prev, [d.id]: parents.length > 0 ? `Parents: ${parents.join(', ')}` : 'No parent domains found.' }))
      fetchDomains()
    } catch {
      setActionMsg(prev => ({ ...prev, [d.id]: 'Error discovering parents.' }))
    } finally {
      setDiscovering(prev => ({ ...prev, [d.id]: false }))
    }
  }

  async function generateConcepts(d: Domain) {
    setGenerating(prev => ({ ...prev, [d.id]: true }))
    setActionMsg(prev => ({ ...prev, [d.id]: '' }))
    try {
      const res = await fetch(`${API}/domains/${d.id}/generate-concepts`, { method: 'POST', headers: authHeaders() })
      if (res.status === 401) { onUnauthorized(); return }
      const data = await res.json()
      const total: number = data.total ?? 0
      setActionMsg(prev => ({ ...prev, [d.id]: `Created ${total} new concept${total === 1 ? '' : 's'}.` }))
      // Invalidate cached concepts so the panel reloads fresh
      setDomainConcepts(prev => { const next = { ...prev }; delete next[d.id]; return next })
    } catch {
      setActionMsg(prev => ({ ...prev, [d.id]: 'Error generating concepts.' }))
    } finally {
      setGenerating(prev => ({ ...prev, [d.id]: false }))
    }
  }

  const tree = buildTree(domains)

  function renderConceptsPanel(node: DomainTreeNode) {
    if (!expandedConcepts[node.id]) return null
    const concepts = domainConcepts[node.id]
    const isLoading = loadingConcepts[node.id]
    return (
      <div className="domain-concepts-panel">
        {isLoading ? (
          <span className="domain-concepts-loading">Loading…</span>
        ) : !concepts || concepts.length === 0 ? (
          <span className="domain-concepts-empty">No concepts yet. Use "Generate Concepts" to seed them.</span>
        ) : (
          <div className="domain-concepts-list">
            {concepts.map(c => (
              <div key={c.id} className="domain-concept-chip">
                <span className="domain-concept-name">{c.canonical_name}</span>
                <span
                  className="domain-concept-level"
                  style={{ color: LEVEL_COLOR[c.level] ?? '#666' }}
                >{c.level}</span>
              </div>
            ))}
          </div>
        )}
      </div>
    )
  }

  function renderNode(node: DomainTreeNode, depth = 0): React.ReactNode {
    const busy = discovering[node.id] || generating[node.id]
    const conceptsOpen = expandedConcepts[node.id]
    const conceptCount = domainConcepts[node.id]?.length
    return (
      <div key={node.id} className="domain-tree-node" style={{ marginLeft: depth * 24 }}>
        <div className="domain-tree-row">
          <div className="domain-tree-info">
            {depth > 0 && <span className="domain-tree-indent-icon">↳</span>}
            <span className="domain-tree-name">{node.name}</span>
            {node.description && <span className="domain-tree-desc">{node.description}</span>}
          </div>
          <div className="domain-tree-actions">
            <button
              className={`btn-sm ${conceptsOpen ? 'btn-primary' : 'btn-secondary'}`}
              onClick={() => toggleConcepts(node)}
              title="Show/hide concepts for this domain"
            >
              {conceptsOpen ? 'Hide Concepts' : `Concepts${conceptCount != null ? ` (${conceptCount})` : ''}`}
            </button>
            {/* <button
              className="btn-sm btn-secondary"
              onClick={() => openEdit(node)}
              disabled={busy}
            >Edit</button> */}
            {/* <button
              className="btn-sm btn-secondary"
              onClick={() => discoverParents(node)}
              disabled={busy}
              title="Ask AI to suggest parent domains"
            >{discovering[node.id] ? '…' : 'Discover Parents'}</button> */}
            <button
              className="btn-sm btn-primary"
              onClick={() => generateConcepts(node)}
              disabled={busy}
              title="Seed foundation concepts for this domain"
            >{generating[node.id] ? '…' : 'Generate Concepts'}</button>
            {/* <button
              className="btn-sm btn-danger"
              onClick={() => deleteDomain(node)}
              disabled={busy}
            >Delete</button> */}
          </div>
        </div>
        {actionMsg[node.id] && (
          <div className="domain-action-msg">{actionMsg[node.id]}</div>
        )}
        {renderConceptsPanel(node)}
        {node.childNodes.map(child => renderNode(child, depth + 1))}
      </div>
    )
  }

  return (
    <div className="domain-manager">
      <div className="domain-manager-header">
        <h2>Domains</h2>
        <button className="btn-primary" onClick={openCreate}>+ New Domain</button>
      </div>

      {error && <div className="error-msg">{error}</div>}

      {loading ? (
        <div className="loading">Loading domains…</div>
      ) : domains.length === 0 ? (
        <div className="empty-state">No domains yet. Create one to get started.</div>
      ) : (
        <div className="domain-tree">
          {tree.map(node => renderNode(node))}
        </div>
      )}

      {showForm && (
        <div className="modal-overlay" onClick={() => setShowForm(false)}>
          <div className="modal-box" onClick={e => e.stopPropagation()}>
            <div className="modal-header">
              <span>{editDomain ? 'Edit Domain' : 'New Domain'}</span>
            </div>
            <div className="modal-body">
              <div className="modal-field">
                <label>Name</label>
                <input
                  type="text"
                  value={formName}
                  onChange={e => setFormName(e.target.value)}
                  placeholder="e.g. machine learning"
                  autoFocus
                />
              </div>
              <div className="modal-field">
                <label>Description</label>
                <textarea
                  className="modal-textarea"
                  value={formDescription}
                  onChange={e => setFormDescription(e.target.value)}
                  placeholder="Optional description"
                  rows={3}
                />
              </div>
              {formError && <div className="error-msg">{formError}</div>}
              <div className="modal-actions">
                <button className="btn-secondary" onClick={() => setShowForm(false)}>Cancel</button>
                <button className="btn-primary" onClick={saveDomain} disabled={formSaving}>
                  {formSaving ? 'Saving…' : 'Save'}
                </button>
              </div>
            </div>
          </div>
        </div>
      )}
    </div>
  )
}
