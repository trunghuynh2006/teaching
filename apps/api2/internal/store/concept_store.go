package store

import (
	"context"

	"github.com/jackc/pgx/v5/pgtype"
)

// ─── Concept ────────────────────────────────────────────────────────────────

type Concept struct {
	ID             string             `json:"id"`
	CanonicalName  string             `json:"canonical_name"`
	Domain         string             `json:"domain"`
	Description    string             `json:"description"`
	Tags           []string           `json:"tags"`
	Level          string             `json:"level"`           // foundation | intermediate | advanced
	Scope          string             `json:"scope"`           // universal | language-specific | framework-specific
	ParentConceptID string            `json:"parent_concept_id"` // optional link to a more general concept
	CreatedBy      string             `json:"created_by"`
	UpdatedBy      string             `json:"updated_by"`
	CreatedTime    pgtype.Timestamptz `json:"created_time"`
	UpdatedTime    pgtype.Timestamptz `json:"updated_time"`
}

type CreateConceptParams struct {
	ID              string
	CanonicalName   string
	Domain          string
	Description     string
	Tags            []string
	Level           string
	Scope           string
	ParentConceptID string
	CreatedBy       string
	UpdatedBy       string
}

type UpdateConceptParams struct {
	ID              string
	CanonicalName   string
	Domain          string
	Description     string
	Tags            []string
	Level           string
	Scope           string
	ParentConceptID string
	UpdatedBy       string
}

const conceptColumns = `id, canonical_name, domain, description, tags, level, scope, COALESCE(parent_concept_id, ''), created_by, updated_by, created_time, updated_time`

// conceptColumnsQ is the same list but every column is table-qualified (alias "c").
// Use this in JOIN queries to avoid ambiguous column errors when the joined
// table also has created_by / created_time columns.
const conceptColumnsQ = `c.id, c.canonical_name, c.domain, c.description, c.tags, c.level, c.scope, COALESCE(c.parent_concept_id, ''), c.created_by, c.updated_by, c.created_time, c.updated_time`

func scanConcept(row interface{ Scan(...any) error }) (Concept, error) {
	var c Concept
	err := row.Scan(&c.ID, &c.CanonicalName, &c.Domain, &c.Description, &c.Tags,
		&c.Level, &c.Scope, &c.ParentConceptID, &c.CreatedBy, &c.UpdatedBy, &c.CreatedTime, &c.UpdatedTime)
	return c, err
}

const createConcept = `
INSERT INTO concepts (id, canonical_name, domain, description, tags, level, scope, parent_concept_id, created_by, updated_by)
VALUES ($1, $2, $3, $4, $5, $6, $7, NULLIF($8, ''), $9, $10)
RETURNING ` + conceptColumns

func (q *Queries) CreateConcept(ctx context.Context, arg CreateConceptParams) (Concept, error) {
	tags := arg.Tags
	if tags == nil {
		tags = []string{}
	}
	level := arg.Level
	if level == "" {
		level = "intermediate"
	}
	scope := arg.Scope
	if scope == "" {
		scope = "universal"
	}
	return scanConcept(q.db.QueryRow(ctx, createConcept,
		arg.ID, arg.CanonicalName, arg.Domain, arg.Description, tags, level, scope,
		arg.ParentConceptID, arg.CreatedBy, arg.UpdatedBy))
}

const listConcepts = `
SELECT ` + conceptColumns + `
FROM concepts
ORDER BY canonical_name ASC
`

func (q *Queries) ListConcepts(ctx context.Context) ([]Concept, error) {
	rows, err := q.db.Query(ctx, listConcepts)
	if err != nil {
		return nil, err
	}
	defer rows.Close()
	var out []Concept
	for rows.Next() {
		c, err := scanConcept(rows)
		if err != nil {
			return nil, err
		}
		out = append(out, c)
	}
	return out, rows.Err()
}

const listConceptsByDomain = `
SELECT ` + conceptColumns + `
FROM concepts
WHERE domain = $1
ORDER BY canonical_name ASC
`

func (q *Queries) ListConceptsByDomain(ctx context.Context, domain string) ([]Concept, error) {
	rows, err := q.db.Query(ctx, listConceptsByDomain, domain)
	if err != nil {
		return nil, err
	}
	defer rows.Close()
	var out []Concept
	for rows.Next() {
		c, err := scanConcept(rows)
		if err != nil {
			return nil, err
		}
		out = append(out, c)
	}
	return out, rows.Err()
}

const getConceptByID = `SELECT ` + conceptColumns + ` FROM concepts WHERE id = $1 LIMIT 1`

func (q *Queries) GetConceptByID(ctx context.Context, id string) (Concept, error) {
	return scanConcept(q.db.QueryRow(ctx, getConceptByID, id))
}

const updateConcept = `
UPDATE concepts
SET canonical_name = $2, domain = $3, description = $4, tags = $5, level = $6, scope = $7,
    parent_concept_id = NULLIF($8, ''), updated_by = $9, updated_time = NOW()
WHERE id = $1
RETURNING ` + conceptColumns

func (q *Queries) UpdateConcept(ctx context.Context, arg UpdateConceptParams) (Concept, error) {
	tags := arg.Tags
	if tags == nil {
		tags = []string{}
	}
	level := arg.Level
	if level == "" {
		level = "intermediate"
	}
	scope := arg.Scope
	if scope == "" {
		scope = "universal"
	}
	return scanConcept(q.db.QueryRow(ctx, updateConcept,
		arg.ID, arg.CanonicalName, arg.Domain, arg.Description, tags, level, scope,
		arg.ParentConceptID, arg.UpdatedBy))
}

const deleteConcept = `DELETE FROM concepts WHERE id = $1`

func (q *Queries) DeleteConcept(ctx context.Context, id string) error {
	_, err := q.db.Exec(ctx, deleteConcept, id)
	return err
}

const initConceptsTable = `
CREATE TABLE IF NOT EXISTS concepts (
    id               VARCHAR(64) PRIMARY KEY,
    canonical_name   VARCHAR(200) NOT NULL,
    domain           VARCHAR(100) NOT NULL DEFAULT '',
    description      TEXT NOT NULL DEFAULT '',
    tags             TEXT[] NOT NULL DEFAULT '{}',
    level            VARCHAR(20) NOT NULL DEFAULT 'intermediate',
    scope            VARCHAR(40) NOT NULL DEFAULT 'universal',
    parent_concept_id VARCHAR(64) REFERENCES concepts(id) ON DELETE SET NULL,
    created_by       VARCHAR(64) NOT NULL DEFAULT '',
    updated_by       VARCHAR(64) NOT NULL DEFAULT '',
    created_time     TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_time     TIMESTAMPTZ NOT NULL DEFAULT NOW()
)
`

func (q *Queries) InitConceptsTable(ctx context.Context) error {
	_, err := q.db.Exec(ctx, initConceptsTable)
	return err
}

const initConceptsDomainIndex = `CREATE INDEX IF NOT EXISTS idx_concepts_domain ON concepts (domain)`

func (q *Queries) InitConceptsDomainIndex(ctx context.Context) error {
	_, err := q.db.Exec(ctx, initConceptsDomainIndex)
	return err
}

// ─── SourceConcept ──────────────────────────────────────────────────────────

type SourceConceptRow struct {
	SourceID    string             `json:"source_id"`
	ConceptID   string             `json:"concept_id"`
	CreatedBy   string             `json:"created_by"`
	CreatedTime pgtype.Timestamptz `json:"created_time"`
}

const linkSourceConcept = `
INSERT INTO source_concepts (source_id, concept_id, created_by)
VALUES ($1, $2, $3)
ON CONFLICT DO NOTHING
`

func (q *Queries) LinkSourceConcept(ctx context.Context, sourceID, conceptID, createdBy string) error {
	_, err := q.db.Exec(ctx, linkSourceConcept, sourceID, conceptID, createdBy)
	return err
}

const unlinkSourceConcept = `DELETE FROM source_concepts WHERE source_id = $1 AND concept_id = $2`

func (q *Queries) UnlinkSourceConcept(ctx context.Context, sourceID, conceptID string) error {
	_, err := q.db.Exec(ctx, unlinkSourceConcept, sourceID, conceptID)
	return err
}

const listConceptsBySource = `
SELECT ` + conceptColumnsQ + `
FROM concepts c
JOIN source_concepts sc ON sc.concept_id = c.id
WHERE sc.source_id = $1
ORDER BY c.canonical_name ASC
`

func (q *Queries) ListConceptsBySource(ctx context.Context, sourceID string) ([]Concept, error) {
	rows, err := q.db.Query(ctx, listConceptsBySource, sourceID)
	if err != nil {
		return nil, err
	}
	defer rows.Close()
	var out []Concept
	for rows.Next() {
		c, err := scanConcept(rows)
		if err != nil {
			return nil, err
		}
		out = append(out, c)
	}
	return out, rows.Err()
}

const initSourceConceptsTable = `
CREATE TABLE IF NOT EXISTS source_concepts (
    source_id    VARCHAR(64) NOT NULL REFERENCES sources(id) ON DELETE CASCADE,
    concept_id   VARCHAR(64) NOT NULL REFERENCES concepts(id) ON DELETE CASCADE,
    created_by   VARCHAR(64) NOT NULL DEFAULT '',
    created_time TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    PRIMARY KEY (source_id, concept_id)
)
`

func (q *Queries) InitSourceConceptsTable(ctx context.Context) error {
	_, err := q.db.Exec(ctx, initSourceConceptsTable)
	return err
}

// ─── TopicConcept ───────────────────────────────────────────────────────────

const linkTopicConcept = `
INSERT INTO topic_concepts (topic_id, concept_id, created_by)
VALUES ($1, $2, $3)
ON CONFLICT DO NOTHING
`

func (q *Queries) LinkTopicConcept(ctx context.Context, topicID, conceptID, createdBy string) error {
	_, err := q.db.Exec(ctx, linkTopicConcept, topicID, conceptID, createdBy)
	return err
}

const unlinkTopicConcept = `DELETE FROM topic_concepts WHERE topic_id = $1 AND concept_id = $2`

func (q *Queries) UnlinkTopicConcept(ctx context.Context, topicID, conceptID string) error {
	_, err := q.db.Exec(ctx, unlinkTopicConcept, topicID, conceptID)
	return err
}

const listConceptsByTopic = `
SELECT ` + conceptColumnsQ + `
FROM concepts c
JOIN topic_concepts tc ON tc.concept_id = c.id
WHERE tc.topic_id = $1
ORDER BY c.canonical_name ASC
`

func (q *Queries) ListConceptsByTopic(ctx context.Context, topicID string) ([]Concept, error) {
	rows, err := q.db.Query(ctx, listConceptsByTopic, topicID)
	if err != nil {
		return nil, err
	}
	defer rows.Close()
	var out []Concept
	for rows.Next() {
		c, err := scanConcept(rows)
		if err != nil {
			return nil, err
		}
		out = append(out, c)
	}
	return out, rows.Err()
}

const initTopicConceptsTable = `
CREATE TABLE IF NOT EXISTS topic_concepts (
    topic_id     VARCHAR(64) NOT NULL REFERENCES topics(id) ON DELETE CASCADE,
    concept_id   VARCHAR(64) NOT NULL REFERENCES concepts(id) ON DELETE CASCADE,
    created_by   VARCHAR(64) NOT NULL DEFAULT '',
    created_time TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    PRIMARY KEY (topic_id, concept_id)
)
`

func (q *Queries) InitTopicConceptsTable(ctx context.Context) error {
	_, err := q.db.Exec(ctx, initTopicConceptsTable)
	return err
}

// ─── Migrations ─────────────────────────────────────────────────────────────

// MigrateConceptParentID adds the parent_concept_id column to an existing concepts table.
func (q *Queries) MigrateConceptParentID(ctx context.Context) error {
	_, err := q.db.Exec(ctx, `ALTER TABLE concepts ADD COLUMN IF NOT EXISTS parent_concept_id VARCHAR(64) REFERENCES concepts(id) ON DELETE SET NULL`)
	return err
}

// MigrateConceptLevelScope adds level and scope columns to an existing concepts table.
func (q *Queries) MigrateConceptLevelScope(ctx context.Context) error {
	stmts := []string{
		`ALTER TABLE concepts ADD COLUMN IF NOT EXISTS level VARCHAR(20) NOT NULL DEFAULT 'intermediate'`,
		`ALTER TABLE concepts ADD COLUMN IF NOT EXISTS scope VARCHAR(40) NOT NULL DEFAULT 'universal'`,
	}
	for _, stmt := range stmts {
		if _, err := q.db.Exec(ctx, stmt); err != nil {
			return err
		}
	}
	return nil
}

const migrateConceptsUniqueConstraint = `
DO $$ BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_constraint WHERE conname = 'uq_concepts_name_domain'
  ) THEN
    ALTER TABLE concepts ADD CONSTRAINT uq_concepts_name_domain UNIQUE (canonical_name, domain);
  END IF;
END $$
`

// MigrateConceptsUniqueConstraint adds a unique constraint on (canonical_name, domain).
func (q *Queries) MigrateConceptsUniqueConstraint(ctx context.Context) error {
	_, err := q.db.Exec(ctx, migrateConceptsUniqueConstraint)
	return err
}

// ─── ConceptPrerequisite ─────────────────────────────────────────────────────

const initConceptPrerequisitesTable = `
CREATE TABLE IF NOT EXISTS concept_prerequisites (
    concept_id    VARCHAR(64) NOT NULL REFERENCES concepts(id) ON DELETE CASCADE,
    prerequisite_id VARCHAR(64) NOT NULL REFERENCES concepts(id) ON DELETE CASCADE,
    created_by    VARCHAR(64) NOT NULL DEFAULT '',
    created_time  TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    PRIMARY KEY (concept_id, prerequisite_id)
)
`

func (q *Queries) InitConceptPrerequisitesTable(ctx context.Context) error {
	_, err := q.db.Exec(ctx, initConceptPrerequisitesTable)
	return err
}

const addConceptPrerequisite = `
INSERT INTO concept_prerequisites (concept_id, prerequisite_id, created_by)
VALUES ($1, $2, $3)
ON CONFLICT DO NOTHING
`

func (q *Queries) AddConceptPrerequisite(ctx context.Context, conceptID, prerequisiteID, createdBy string) error {
	_, err := q.db.Exec(ctx, addConceptPrerequisite, conceptID, prerequisiteID, createdBy)
	return err
}

const removeConceptPrerequisite = `DELETE FROM concept_prerequisites WHERE concept_id = $1 AND prerequisite_id = $2`

func (q *Queries) RemoveConceptPrerequisite(ctx context.Context, conceptID, prerequisiteID string) error {
	_, err := q.db.Exec(ctx, removeConceptPrerequisite, conceptID, prerequisiteID)
	return err
}

const listConceptPrerequisites = `
SELECT ` + conceptColumnsQ + `
FROM concepts c
JOIN concept_prerequisites cp ON cp.prerequisite_id = c.id
WHERE cp.concept_id = $1
ORDER BY c.level ASC, c.canonical_name ASC
`

func (q *Queries) ListConceptPrerequisites(ctx context.Context, conceptID string) ([]Concept, error) {
	rows, err := q.db.Query(ctx, listConceptPrerequisites, conceptID)
	if err != nil {
		return nil, err
	}
	defer rows.Close()
	var out []Concept
	for rows.Next() {
		c, err := scanConcept(rows)
		if err != nil {
			return nil, err
		}
		out = append(out, c)
	}
	return out, rows.Err()
}

const listConceptDependents = `
SELECT ` + conceptColumnsQ + `
FROM concepts c
JOIN concept_prerequisites cp ON cp.concept_id = c.id
WHERE cp.prerequisite_id = $1
ORDER BY c.level ASC, c.canonical_name ASC
`

func (q *Queries) ListConceptDependents(ctx context.Context, conceptID string) ([]Concept, error) {
	rows, err := q.db.Query(ctx, listConceptDependents, conceptID)
	if err != nil {
		return nil, err
	}
	defer rows.Close()
	var out []Concept
	for rows.Next() {
		c, err := scanConcept(rows)
		if err != nil {
			return nil, err
		}
		out = append(out, c)
	}
	return out, rows.Err()
}
