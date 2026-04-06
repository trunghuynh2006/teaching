package store

import (
	"context"

	"github.com/jackc/pgx/v5/pgtype"
)

// ─── Domain ─────────────────────────────────────────────────────────────────

type Domain struct {
	ID          string             `json:"id"`
	Name        string             `json:"name"`
	Description string             `json:"description"`
	CreatedBy   string             `json:"created_by"`
	UpdatedBy   string             `json:"updated_by"`
	CreatedTime pgtype.Timestamptz `json:"created_time"`
	UpdatedTime pgtype.Timestamptz `json:"updated_time"`
}

type CreateDomainParams struct {
	ID          string
	Name        string
	Description string
	CreatedBy   string
	UpdatedBy   string
}

type UpdateDomainParams struct {
	ID          string
	Name        string
	Description string
	UpdatedBy   string
}

const domainColumns = `id, name, description, created_by, updated_by, created_time, updated_time`

func scanDomain(row interface{ Scan(...any) error }) (Domain, error) {
	var d Domain
	err := row.Scan(&d.ID, &d.Name, &d.Description, &d.CreatedBy, &d.UpdatedBy, &d.CreatedTime, &d.UpdatedTime)
	return d, err
}

const initDomainsTable = `
CREATE TABLE IF NOT EXISTS domains (
    id           VARCHAR(64) PRIMARY KEY,
    name         VARCHAR(200) NOT NULL,
    description  TEXT NOT NULL DEFAULT '',
    created_by   VARCHAR(64) NOT NULL DEFAULT '',
    updated_by   VARCHAR(64) NOT NULL DEFAULT '',
    created_time TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_time TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    CONSTRAINT uq_domains_name UNIQUE (name)
)
`

func (q *Queries) InitDomainsTable(ctx context.Context) error {
	_, err := q.db.Exec(ctx, initDomainsTable)
	return err
}

const createDomain = `
INSERT INTO domains (id, name, description, created_by, updated_by)
VALUES ($1, $2, $3, $4, $5)
RETURNING ` + domainColumns

func (q *Queries) CreateDomain(ctx context.Context, arg CreateDomainParams) (Domain, error) {
	return scanDomain(q.db.QueryRow(ctx, createDomain,
		arg.ID, arg.Name, arg.Description, arg.CreatedBy, arg.UpdatedBy))
}

const listDomains = `SELECT ` + domainColumns + ` FROM domains ORDER BY name ASC`

func (q *Queries) ListDomains(ctx context.Context) ([]Domain, error) {
	rows, err := q.db.Query(ctx, listDomains)
	if err != nil {
		return nil, err
	}
	defer rows.Close()
	var out []Domain
	for rows.Next() {
		d, err := scanDomain(rows)
		if err != nil {
			return nil, err
		}
		out = append(out, d)
	}
	return out, rows.Err()
}

const getDomainByID = `SELECT ` + domainColumns + ` FROM domains WHERE id = $1 LIMIT 1`

func (q *Queries) GetDomainByID(ctx context.Context, id string) (Domain, error) {
	return scanDomain(q.db.QueryRow(ctx, getDomainByID, id))
}

const getDomainByName = `SELECT ` + domainColumns + ` FROM domains WHERE name = $1 LIMIT 1`

func (q *Queries) GetDomainByName(ctx context.Context, name string) (Domain, error) {
	return scanDomain(q.db.QueryRow(ctx, getDomainByName, name))
}

const updateDomain = `
UPDATE domains
SET name = $2, description = $3, updated_by = $4, updated_time = NOW()
WHERE id = $1
RETURNING ` + domainColumns

func (q *Queries) UpdateDomain(ctx context.Context, arg UpdateDomainParams) (Domain, error) {
	return scanDomain(q.db.QueryRow(ctx, updateDomain,
		arg.ID, arg.Name, arg.Description, arg.UpdatedBy))
}

const deleteDomain = `DELETE FROM domains WHERE id = $1`

func (q *Queries) DeleteDomain(ctx context.Context, id string) error {
	_, err := q.db.Exec(ctx, deleteDomain, id)
	return err
}

// ─── DomainPrerequisite (parent-child relationships) ─────────────────────────
// "prerequisite" means parent: domain X has prerequisite Y means Y is the parent domain.

const initDomainPrerequisitesTable = `
CREATE TABLE IF NOT EXISTS domain_prerequisites (
    domain         VARCHAR(200) NOT NULL,
    prerequisite   VARCHAR(200) NOT NULL,
    created_by     VARCHAR(64) NOT NULL DEFAULT '',
    created_time   TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    PRIMARY KEY (domain, prerequisite)
)
`

func (q *Queries) InitDomainPrerequisitesTable(ctx context.Context) error {
	_, err := q.db.Exec(ctx, initDomainPrerequisitesTable)
	return err
}

const addDomainPrerequisite = `
INSERT INTO domain_prerequisites (domain, prerequisite, created_by)
VALUES ($1, $2, $3)
ON CONFLICT DO NOTHING
`

func (q *Queries) AddDomainPrerequisite(ctx context.Context, domain, prerequisite, createdBy string) error {
	_, err := q.db.Exec(ctx, addDomainPrerequisite, domain, prerequisite, createdBy)
	return err
}

const removeDomainPrerequisite = `DELETE FROM domain_prerequisites WHERE domain = $1 AND prerequisite = $2`

func (q *Queries) RemoveDomainPrerequisite(ctx context.Context, domain, prerequisite string) error {
	_, err := q.db.Exec(ctx, removeDomainPrerequisite, domain, prerequisite)
	return err
}

// ListDomainParents returns all prerequisite (parent) domain names for a domain.
const listDomainParents = `
SELECT prerequisite FROM domain_prerequisites
WHERE domain = $1
ORDER BY prerequisite ASC
`

func (q *Queries) ListDomainParents(ctx context.Context, domain string) ([]string, error) {
	rows, err := q.db.Query(ctx, listDomainParents, domain)
	if err != nil {
		return nil, err
	}
	defer rows.Close()
	var out []string
	for rows.Next() {
		var s string
		if err := rows.Scan(&s); err != nil {
			return nil, err
		}
		out = append(out, s)
	}
	return out, rows.Err()
}

// ListDomainChildren returns all domain names that have this domain as a prerequisite (parent).
const listDomainChildren = `
SELECT domain FROM domain_prerequisites
WHERE prerequisite = $1
ORDER BY domain ASC
`

func (q *Queries) ListDomainChildren(ctx context.Context, prerequisite string) ([]string, error) {
	rows, err := q.db.Query(ctx, listDomainChildren, prerequisite)
	if err != nil {
		return nil, err
	}
	defer rows.Close()
	var out []string
	for rows.Next() {
		var s string
		if err := rows.Scan(&s); err != nil {
			return nil, err
		}
		out = append(out, s)
	}
	return out, rows.Err()
}

// ListAllDomainPrerequisites returns the full domain->prerequisite mapping table.
type DomainPrerequisiteRow struct {
	Domain      string `json:"domain"`
	Prerequisite string `json:"prerequisite"`
}

const listAllDomainPrerequisites = `SELECT domain, prerequisite FROM domain_prerequisites ORDER BY domain ASC, prerequisite ASC`

func (q *Queries) ListAllDomainPrerequisites(ctx context.Context) ([]DomainPrerequisiteRow, error) {
	rows, err := q.db.Query(ctx, listAllDomainPrerequisites)
	if err != nil {
		return nil, err
	}
	defer rows.Close()
	var out []DomainPrerequisiteRow
	for rows.Next() {
		var r DomainPrerequisiteRow
		if err := rows.Scan(&r.Domain, &r.Prerequisite); err != nil {
			return nil, err
		}
		out = append(out, r)
	}
	return out, rows.Err()
}
