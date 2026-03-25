-- =============================================================================
-- seed_data.sql  — Demo content for self-exploration and demo sessions
-- Covers all entities under schemas/content/ and schemas/knowledge/
-- Safe to re-run: all inserts use ON CONFLICT DO NOTHING
-- =============================================================================

-- ---------------------------------------------------------------------------
-- 0. Schema migrations — ensure columns/tables added after initial schema.sql
--    These are idempotent (ADD COLUMN IF NOT EXISTS / CREATE TABLE IF NOT EXISTS)
-- ---------------------------------------------------------------------------

ALTER TABLE folders ADD COLUMN IF NOT EXISTS folder_type VARCHAR(20) NOT NULL DEFAULT 'teacher';
ALTER TABLE folders ADD COLUMN IF NOT EXISTS owner_id    VARCHAR(64);
ALTER TABLE folders ADD COLUMN IF NOT EXISTS program_id  VARCHAR(64);
ALTER TABLE folders ADD COLUMN IF NOT EXISTS is_locked   BOOLEAN NOT NULL DEFAULT FALSE;
ALTER TABLE folders ADD COLUMN IF NOT EXISTS domain      VARCHAR(100);
ALTER TABLE folders ADD COLUMN IF NOT EXISTS theme       VARCHAR(50) NOT NULL DEFAULT '';
ALTER TABLE folders ADD COLUMN IF NOT EXISTS icon        VARCHAR(50) NOT NULL DEFAULT '';

CREATE TABLE IF NOT EXISTS folder_members (
    folder_id  VARCHAR(64) NOT NULL REFERENCES folders(id) ON DELETE CASCADE,
    user_id    VARCHAR(64) NOT NULL,
    role       VARCHAR(20) NOT NULL DEFAULT 'viewer',
    added_by   VARCHAR(64),
    added_time TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    PRIMARY KEY (folder_id, user_id)
);

-- ---------------------------------------------------------------------------
-- 1. Missing tables (entities that exist in schemas but not yet in the DB)
-- ---------------------------------------------------------------------------

CREATE TABLE IF NOT EXISTS concepts (
    id           VARCHAR(64) PRIMARY KEY,
    canonical_name VARCHAR(200) NOT NULL,
    domain       VARCHAR(100),
    description  TEXT,
    tags         TEXT[] NOT NULL DEFAULT '{}',
    created_by   VARCHAR(64),
    updated_by   VARCHAR(64),
    created_time TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_time TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS concept_aliases (
    id           VARCHAR(64) PRIMARY KEY,
    concept_id   VARCHAR(64) NOT NULL REFERENCES concepts(id) ON DELETE CASCADE,
    alias        VARCHAR(200) NOT NULL,
    created_by   VARCHAR(64),
    created_time TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS concept_relations (
    concept_a_id  VARCHAR(64) NOT NULL REFERENCES concepts(id) ON DELETE CASCADE,
    concept_b_id  VARCHAR(64) NOT NULL REFERENCES concepts(id) ON DELETE CASCADE,
    relation_type VARCHAR(50) NOT NULL,
    created_by    VARCHAR(64),
    created_time  TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    PRIMARY KEY (concept_a_id, concept_b_id, relation_type)
);

CREATE TABLE IF NOT EXISTS topics (
    id           VARCHAR(64) PRIMARY KEY,
    name         VARCHAR(200) NOT NULL,
    folder_id    VARCHAR(64) NOT NULL REFERENCES folders(id) ON DELETE CASCADE,
    description  TEXT NOT NULL DEFAULT '',
    created_by   VARCHAR(64) NOT NULL DEFAULT '',
    updated_by   VARCHAR(64) NOT NULL DEFAULT '',
    created_time TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_time TIMESTAMPTZ NOT NULL DEFAULT NOW()
);
CREATE INDEX IF NOT EXISTS idx_topics_folder_id ON topics (folder_id);

CREATE TABLE IF NOT EXISTS topic_concepts (
    topic_id     VARCHAR(64) NOT NULL REFERENCES topics(id) ON DELETE CASCADE,
    concept_id   VARCHAR(64) NOT NULL REFERENCES concepts(id) ON DELETE CASCADE,
    position     INTEGER NOT NULL DEFAULT 0,
    PRIMARY KEY (topic_id, concept_id)
);

CREATE TABLE IF NOT EXISTS books (
    id           VARCHAR(64) PRIMARY KEY,
    source_id    VARCHAR(64) NOT NULL UNIQUE REFERENCES sources(id) ON DELETE CASCADE,
    author       VARCHAR(200),
    isbn         VARCHAR(50),
    published_at DATE,
    created_by   VARCHAR(64),
    updated_by   VARCHAR(64),
    created_time TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_time TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS chapters (
    id           VARCHAR(64) PRIMARY KEY,
    book_id      VARCHAR(64) NOT NULL REFERENCES books(id) ON DELETE CASCADE,
    title        VARCHAR(200) NOT NULL,
    content      TEXT NOT NULL DEFAULT '',
    position     INTEGER NOT NULL DEFAULT 0,
    created_by   VARCHAR(64),
    updated_by   VARCHAR(64),
    created_time TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_time TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS source_concepts (
    source_id    VARCHAR(64) NOT NULL REFERENCES sources(id) ON DELETE CASCADE,
    concept_id   VARCHAR(64) NOT NULL REFERENCES concepts(id) ON DELETE CASCADE,
    created_by   VARCHAR(64),
    created_time TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    PRIMARY KEY (source_id, concept_id)
);

CREATE TABLE IF NOT EXISTS source_topics (
    source_id    VARCHAR(64) NOT NULL REFERENCES sources(id) ON DELETE CASCADE,
    topic_id     VARCHAR(64) NOT NULL REFERENCES topics(id) ON DELETE CASCADE,
    created_by   VARCHAR(64),
    created_time TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    PRIMARY KEY (source_id, topic_id)
);

-- ---------------------------------------------------------------------------
-- 2. Folders
-- ---------------------------------------------------------------------------

INSERT INTO folders (id, folder_type, owner_id, is_locked, name, description, domain, theme, icon, created_by, updated_by)
VALUES
    ('folder_email001',
     'teacher', 'teacher_john', false,
     'Writing Effective Email',
     'Learn how to craft professional emails that are clear, concise, and get results.',
     'communication', 'blue', 'email',
     'teacher_john', 'teacher_john'),

    ('folder_electricity001',
     'teacher', 'teacher_nina', false,
     'Basic Electricity',
     'Foundations of electrical circuits, Ohm''s Law, and circuit analysis.',
     'physics', 'yellow', 'bolt',
     'teacher_nina', 'teacher_nina')
ON CONFLICT (id) DO NOTHING;

-- ---------------------------------------------------------------------------
-- 3. Folder members  (learners get shared access)
-- ---------------------------------------------------------------------------

INSERT INTO folder_members (folder_id, user_id, role, added_by)
VALUES
    ('folder_email001',       'learner_alex', 'editor', 'teacher_john'),
    ('folder_email001',       'learner_mia',  'viewer', 'teacher_john'),
    ('folder_electricity001', 'learner_alex', 'viewer', 'teacher_nina'),
    ('folder_electricity001', 'learner_mia',  'editor', 'teacher_nina')
ON CONFLICT (folder_id, user_id) DO NOTHING;

-- ---------------------------------------------------------------------------
-- 4. Concepts  (global, reusable knowledge units)
-- ---------------------------------------------------------------------------

INSERT INTO concepts (id, canonical_name, domain, description, tags, created_by, updated_by)
VALUES
    -- Communication domain
    ('concept_subjectline01', 'Subject Line',
     'communication',
     'The first line of an email visible in the inbox, summarising the message purpose.',
     ARRAY['email','writing','inbox'], 'teacher_john', 'teacher_john'),

    ('concept_cta001', 'Call to Action',
     'communication',
     'A clear instruction that tells the reader what to do next.',
     ARRAY['email','writing','engagement'], 'teacher_john', 'teacher_john'),

    ('concept_tone001', 'Professional Tone',
     'communication',
     'The level of formality and register appropriate for workplace communication.',
     ARRAY['email','writing','formality'], 'teacher_john', 'teacher_john'),

    ('concept_salutation01', 'Email Salutation',
     'communication',
     'The opening greeting of an email (e.g. "Dear …", "Hi …").',
     ARRAY['email','writing','greeting'], 'teacher_john', 'teacher_john'),

    -- Physics domain
    ('concept_ohmslaw001', 'Ohm''s Law',
     'physics',
     'V = IR — the voltage across a conductor equals the product of current and resistance.',
     ARRAY['electricity','circuit','law'], 'teacher_nina', 'teacher_nina'),

    ('concept_resistance01', 'Resistance',
     'physics',
     'The opposition to the flow of electric current, measured in ohms (Ω).',
     ARRAY['electricity','circuit','component'], 'teacher_nina', 'teacher_nina'),

    ('concept_current001', 'Electric Current',
     'physics',
     'The flow of electric charge through a conductor, measured in amperes (A).',
     ARRAY['electricity','circuit','charge'], 'teacher_nina', 'teacher_nina'),

    ('concept_voltage001', 'Voltage',
     'physics',
     'The electric potential difference between two points, measured in volts (V).',
     ARRAY['electricity','circuit','potential'], 'teacher_nina', 'teacher_nina')
ON CONFLICT (id) DO NOTHING;

-- ---------------------------------------------------------------------------
-- 5. Concept aliases
-- ---------------------------------------------------------------------------

INSERT INTO concept_aliases (id, concept_id, alias, created_by)
VALUES
    ('alias_subjectline01', 'concept_subjectline01', 'email subject',       'teacher_john'),
    ('alias_subjectline02', 'concept_subjectline01', 'subject header',      'teacher_john'),
    ('alias_ohmslaw001',    'concept_ohmslaw001',    'Ohm''s equation',     'teacher_nina'),
    ('alias_ohmslaw002',    'concept_ohmslaw001',    'V=IR',                'teacher_nina'),
    ('alias_current001',    'concept_current001',    'current flow',        'teacher_nina'),
    ('alias_current002',    'concept_current001',    'amperage',            'teacher_nina'),
    ('alias_resist001',     'concept_resistance01',  'electrical resistance','teacher_nina'),
    ('alias_resist002',     'concept_resistance01',  'impedance',           'teacher_nina')
ON CONFLICT (id) DO NOTHING;

-- ---------------------------------------------------------------------------
-- 6. Concept relations
-- ---------------------------------------------------------------------------

INSERT INTO concept_relations (concept_a_id, concept_b_id, relation_type, created_by)
VALUES
    -- Ohm's Law requires knowing voltage and resistance first
    ('concept_voltage001',   'concept_ohmslaw001',  'prerequisite', 'teacher_nina'),
    ('concept_resistance01', 'concept_ohmslaw001',  'prerequisite', 'teacher_nina'),
    -- Current and resistance are related (both part of Ohm's Law)
    ('concept_current001',   'concept_resistance01','related_to',   'teacher_nina'),
    -- Current is a part of voltage-difference
    ('concept_current001',   'concept_voltage001',  'part_of',      'teacher_nina'),
    -- CTA relates to professional tone
    ('concept_cta001',       'concept_tone001',     'related_to',   'teacher_john'),
    -- Salutation is part of professional tone
    ('concept_salutation01', 'concept_tone001',     'part_of',      'teacher_john')
ON CONFLICT (concept_a_id, concept_b_id, relation_type) DO NOTHING;

-- ---------------------------------------------------------------------------
-- 7. Topics (belong to a folder, group related concepts)
-- ---------------------------------------------------------------------------

INSERT INTO topics (id, name, folder_id, description, created_by, updated_by)
VALUES
    ('topic_emailstruct01', 'Email Structure',
     'folder_email001',
     'How to organise an email: subject line, salutation, body, and sign-off.',
     'teacher_john', 'teacher_john'),

    ('topic_emailtone001', 'Professional Tone',
     'folder_email001',
     'Choosing the right register and tone for different professional contexts.',
     'teacher_john', 'teacher_john'),

    ('topic_basiclaws001', 'Basic Circuit Laws',
     'folder_electricity001',
     'Fundamental laws governing voltage, current, and resistance in circuits.',
     'teacher_nina', 'teacher_nina'),

    ('topic_circuittypes01', 'Circuit Types',
     'folder_electricity001',
     'Understanding series circuits, parallel circuits, and their properties.',
     'teacher_nina', 'teacher_nina')
ON CONFLICT (id) DO NOTHING;

-- Concepts within each topic (ordered)
INSERT INTO topic_concepts (topic_id, concept_id)
VALUES
    ('topic_emailstruct01', 'concept_subjectline01'),
    ('topic_emailstruct01', 'concept_salutation01'),
    ('topic_emailtone001',  'concept_tone001'),
    ('topic_emailtone001',  'concept_cta001'),
    ('topic_basiclaws001',  'concept_voltage001'),
    ('topic_basiclaws001',  'concept_resistance01'),
    ('topic_basiclaws001',  'concept_ohmslaw001'),
    ('topic_circuittypes01','concept_current001'),
    ('topic_circuittypes01','concept_voltage001')
ON CONFLICT (topic_id, concept_id) DO NOTHING;

-- ---------------------------------------------------------------------------
-- 8. Sources (text content belonging to folders)
-- ---------------------------------------------------------------------------

INSERT INTO sources (id, folder_id, title, content, created_by, updated_by)
VALUES
    ('src_subjectline001', 'folder_email001',
     'Subject Lines That Get Opened',
     'A great subject line is the most important part of any email. Research shows that 47% of email recipients open an email based on the subject line alone.

Key principles:
• Keep it under 50 characters so it displays fully on mobile.
• Be specific: "Q3 Budget Review — Action Required by Friday" beats "Important".
• Use the recipient''s name or their project to personalise.
• Avoid spam triggers: ALL CAPS, excessive punctuation, or words like "FREE!!!"
• A/B test subject lines when sending to large groups to learn what resonates.

Examples of weak vs. strong subject lines:
  Weak:  "Following up"
  Strong: "Following up on the proposal we discussed Tuesday — next steps?"

  Weak:  "Meeting"
  Strong: "Can we meet Thursday 2pm to align on the product launch?"',
     'teacher_john', 'teacher_john'),

    ('src_emailtone001', 'folder_email001',
     'Tone and Formality in Professional Emails',
     'The tone of your email shapes how the reader perceives you and your organisation. Choosing the wrong level of formality can come across as either cold or too casual.

Levels of formality:
1. Formal — Use for initial contact, senior stakeholders, or sensitive topics.
   Salutation: "Dear Ms. Patel,"  |  Sign-off: "Yours sincerely,"
2. Semi-formal — Everyday workplace communication with colleagues you know.
   Salutation: "Hi Nina,"  |  Sign-off: "Best regards,"
3. Informal — Close colleagues or internal quick notes.
   Salutation: "Hey,"  |  Sign-off: "Cheers,"

Rules of thumb:
• Mirror the formality level of the person who emailed you first.
• When in doubt, start more formal — it''s easy to relax over time.
• Avoid jargon and acronyms unless you are certain the reader knows them.
• Keep sentences short. One idea per sentence.
• End with a clear call to action so the reader knows what is expected.',
     'teacher_john', 'teacher_john'),

    ('src_ohmslaw001', 'folder_electricity001',
     'Ohm''s Law and Resistance',
     'Ohm''s Law is the cornerstone of circuit analysis. It states that the current through a conductor between two points is directly proportional to the voltage across the two points and inversely proportional to the resistance.

Formula:  V = I × R

Where:
  V = Voltage in volts (V)
  I = Current in amperes (A)
  R = Resistance in ohms (Ω)

Derived forms:
  I = V / R   (find current when voltage and resistance are known)
  R = V / I   (find resistance when voltage and current are known)

Example problem:
  A 12 V battery is connected to a resistor. The current measured is 2 A.
  What is the resistance?
  R = V / I = 12 / 2 = 6 Ω

Resistance depends on:
  • Material — copper has low resistance; rubber has high resistance.
  • Length — longer wire → higher resistance.
  • Cross-sectional area — thicker wire → lower resistance.
  • Temperature — for most metals, resistance increases with temperature.',
     'teacher_nina', 'teacher_nina'),

    ('src_circuits001', 'folder_electricity001',
     'Series and Parallel Circuits',
     'Understanding how components are connected in a circuit is essential for predicting how the circuit behaves.

Series circuits:
  Components are connected end-to-end in a single path.
  • The same current flows through every component.
  • Total resistance: R_total = R1 + R2 + R3 + …
  • Voltage divides across components.
  • If one component fails (open circuit), the whole circuit stops.

Parallel circuits:
  Components are connected across the same two nodes (multiple paths).
  • The same voltage appears across every branch.
  • Total resistance: 1/R_total = 1/R1 + 1/R2 + 1/R3 + …
  • Current divides between branches.
  • If one branch fails, other branches continue to operate.

Comparison table:
  Property        | Series          | Parallel
  Current         | Same everywhere | Splits between branches
  Voltage         | Splits          | Same across branches
  Resistance      | Increases       | Decreases (always less than smallest)
  Fault tolerance | Low             | High

Real-world examples:
  Series — old Christmas light strings (one bulb out = all out).
  Parallel — household wiring (one appliance off ≠ others off).',
     'teacher_nina', 'teacher_nina')
ON CONFLICT (id) DO NOTHING;

-- ---------------------------------------------------------------------------
-- 9. Books (extend a source with book metadata)
-- ---------------------------------------------------------------------------

INSERT INTO books (id, source_id, author, published_at, created_by, updated_by)
VALUES
    ('book_emailguide001', 'src_subjectline001',
     'John Carter', '2024-01-15', 'teacher_john', 'teacher_john'),

    ('book_electricguide01', 'src_ohmslaw001',
     'Nina Patel', '2023-09-01', 'teacher_nina', 'teacher_nina')
ON CONFLICT (id) DO NOTHING;

-- ---------------------------------------------------------------------------
-- 10. Chapters
-- ---------------------------------------------------------------------------

INSERT INTO chapters (id, book_id, title, content, position, created_by, updated_by)
VALUES
    ('chap_email_01', 'book_emailguide001',
     'Why Subject Lines Make or Break Your Email',
     'In the age of overflowing inboxes, your subject line is your first — and sometimes only — chance to be noticed. Studies consistently show that nearly half of all recipients decide whether to open an email based solely on its subject line. A compelling subject line does not just describe the email; it creates a reason to open it. This chapter explores the psychology behind subject lines and the practical rules that separate emails that get opened from those that get deleted.',
     0, 'teacher_john', 'teacher_john'),

    ('chap_email_02', 'book_emailguide001',
     'Keywords, Personalisation, and A/B Testing',
     'Once you understand why subject lines matter, the next step is mastering the craft. This chapter covers three powerful techniques: using action-oriented keywords (e.g. "Action required", "Your invitation"), personalising with the recipient''s name or context, and systematically improving through A/B testing. We will walk through real examples and show how small wording changes can double your open rate.',
     1, 'teacher_john', 'teacher_john'),

    ('chap_elec_01', 'book_electricguide01',
     'What Is Ohm''s Law and Why Does It Matter?',
     'Georg Simon Ohm published his law in 1827, and it remains the most frequently used relationship in electrical engineering. This chapter introduces the law intuitively — before touching a single formula — by asking: what happens when you increase the push (voltage) on water flowing through a narrow pipe (resistance)? Once the intuition is clear, we formalise it as V = IR and work through practical calculations step by step.',
     0, 'teacher_nina', 'teacher_nina'),

    ('chap_elec_02', 'book_electricguide01',
     'Calculating Resistance in Real Components',
     'Resistance is not just a number on a datasheet — it depends on material, geometry, and temperature. This chapter shows you how to calculate the resistance of a copper wire versus an aluminium wire of the same length, how resistors are colour-coded for quick identification, and how to use a multimeter to measure resistance directly. By the end you will be able to predict how a circuit will behave before connecting a single wire.',
     1, 'teacher_nina', 'teacher_nina')
ON CONFLICT (id) DO NOTHING;

-- ---------------------------------------------------------------------------
-- 11. Source ↔ Concept mappings
-- ---------------------------------------------------------------------------

INSERT INTO source_concepts (source_id, concept_id, created_by)
VALUES
    ('src_subjectline001', 'concept_subjectline01', 'teacher_john'),
    ('src_subjectline001', 'concept_cta001',         'teacher_john'),
    ('src_emailtone001',   'concept_tone001',         'teacher_john'),
    ('src_emailtone001',   'concept_salutation01',   'teacher_john'),
    ('src_ohmslaw001',     'concept_ohmslaw001',      'teacher_nina'),
    ('src_ohmslaw001',     'concept_resistance01',    'teacher_nina'),
    ('src_circuits001',    'concept_current001',      'teacher_nina'),
    ('src_circuits001',    'concept_voltage001',      'teacher_nina')
ON CONFLICT (source_id, concept_id) DO NOTHING;

-- ---------------------------------------------------------------------------
-- 12. Source ↔ Topic mappings
-- ---------------------------------------------------------------------------

INSERT INTO source_topics (source_id, topic_id, created_by)
VALUES
    ('src_subjectline001', 'topic_emailstruct01',  'teacher_john'),
    ('src_emailtone001',   'topic_emailtone001',   'teacher_john'),
    ('src_ohmslaw001',     'topic_basiclaws001',   'teacher_nina'),
    ('src_circuits001',    'topic_circuittypes01', 'teacher_nina')
ON CONFLICT (source_id, topic_id) DO NOTHING;

-- =============================================================================
-- Microsoft Certified: Power Platform Developer Associate (PL-400)
-- 100 concepts across 10 topics
-- =============================================================================

-- ---------------------------------------------------------------------------
-- Folder
-- ---------------------------------------------------------------------------

INSERT INTO folders (id, folder_type, owner_id, is_locked, name, description, domain, theme, icon, created_by, updated_by)
VALUES
    ('folder_powerplatform01',
     'teacher', 'teacher_john', false,
     'Microsoft Certified: Power Platform Developer Associate',
     'Complete study material for the PL-400 exam covering Dataverse, Power Apps, Power Automate, plugins, PCF, integrations, ALM, and governance.',
     'software', 'purple', 'cloud',
     'teacher_john', 'teacher_john')
ON CONFLICT (id) DO NOTHING;

INSERT INTO folder_members (folder_id, user_id, role, added_by)
VALUES
    ('folder_powerplatform01', 'learner_alex', 'viewer', 'teacher_john'),
    ('folder_powerplatform01', 'learner_mia',  'viewer', 'teacher_john')
ON CONFLICT (folder_id, user_id) DO NOTHING;

-- ---------------------------------------------------------------------------
-- 100 Concepts
-- ---------------------------------------------------------------------------

INSERT INTO concepts (id, canonical_name, domain, description, tags, created_by, updated_by)
VALUES

-- ── Group 1: Dataverse Fundamentals ──────────────────────────────────────────
('concept_pp_dataverse01', 'Microsoft Dataverse',
 'software',
 'Cloud-based data storage platform used by Power Platform apps to securely store and manage business data.',
 ARRAY['dataverse','power-platform','pl-400'], 'teacher_john', 'teacher_john'),

('concept_pp_table01', 'Dataverse Table',
 'software',
 'A structured container of rows and columns in Dataverse, equivalent to a database table, formerly called an Entity.',
 ARRAY['dataverse','table','schema','pl-400'], 'teacher_john', 'teacher_john'),

('concept_pp_columntype01', 'Column Data Types',
 'software',
 'The set of available column types in Dataverse: Text, Number, Date/Time, Choice, Lookup, Currency, File, and Image.',
 ARRAY['dataverse','column','schema','pl-400'], 'teacher_john', 'teacher_john'),

('concept_pp_onetomany01', 'One-to-Many Relationship',
 'software',
 'A Dataverse table relationship where one row in a parent table relates to multiple rows in a child table via a Lookup column.',
 ARRAY['dataverse','relationship','schema','pl-400'], 'teacher_john', 'teacher_john'),

('concept_pp_manytomany01', 'Many-to-Many Relationship',
 'software',
 'A Dataverse relationship where rows in two tables can each be associated with multiple rows in the other, backed by an intersect table.',
 ARRAY['dataverse','relationship','schema','pl-400'], 'teacher_john', 'teacher_john'),

('concept_pp_solution01', 'Solution',
 'software',
 'A container for Power Platform customizations used to package and transport components (apps, flows, tables) across environments.',
 ARRAY['alm','solution','power-platform','pl-400'], 'teacher_john', 'teacher_john'),

('concept_pp_publisher01', 'Solution Publisher',
 'software',
 'Defines the customization prefix (e.g. "contoso_") applied to all solution components; identifies the vendor of a solution.',
 ARRAY['alm','solution','prefix','pl-400'], 'teacher_john', 'teacher_john'),

('concept_pp_managed01', 'Managed vs Unmanaged Solution',
 'software',
 'Managed solutions are locked, distributable packages; unmanaged solutions allow direct customization and are used during development.',
 ARRAY['alm','solution','deployment','pl-400'], 'teacher_john', 'teacher_john'),

('concept_pp_securityrole01', 'Security Role',
 'software',
 'A set of privileges that define what operations (Create, Read, Update, Delete) a user can perform on Dataverse tables.',
 ARRAY['security','dataverse','access-control','pl-400'], 'teacher_john', 'teacher_john'),

('concept_pp_businessunit01', 'Business Unit',
 'software',
 'A hierarchical organizational unit in Dataverse used to group users and control data access scope through security roles.',
 ARRAY['security','dataverse','organization','pl-400'], 'teacher_john', 'teacher_john'),

-- ── Group 2: Dataverse Advanced Features ─────────────────────────────────────
('concept_pp_calculated01', 'Calculated Column',
 'software',
 'A Dataverse column whose value is automatically computed from a formula referencing other columns in the same row.',
 ARRAY['dataverse','column','formula','pl-400'], 'teacher_john', 'teacher_john'),

('concept_pp_rollup01', 'Rollup Column',
 'software',
 'A Dataverse column that aggregates values (sum, count, min, max, avg) from related child rows on a scheduled basis.',
 ARRAY['dataverse','column','aggregation','pl-400'], 'teacher_john', 'teacher_john'),

('concept_pp_altkey01', 'Alternate Key',
 'software',
 'A unique key defined on one or more columns that can identify a Dataverse row without using the primary GUID, used for upsert operations.',
 ARRAY['dataverse','schema','upsert','pl-400'], 'teacher_john', 'teacher_john'),

('concept_pp_elastictable01', 'Elastic Table',
 'software',
 'A Dataverse table type built on Azure Cosmos DB, designed for high-volume, high-velocity scenarios with flexible schemas.',
 ARRAY['dataverse','table','nosql','pl-400'], 'teacher_john', 'teacher_john'),

('concept_pp_auditlog01', 'Audit Log',
 'software',
 'Dataverse feature that records who created, modified, or deleted records and when, for compliance and troubleshooting.',
 ARRAY['dataverse','audit','governance','pl-400'], 'teacher_john', 'teacher_john'),

('concept_pp_dvsearch01', 'Dataverse Search',
 'software',
 'A full-text, relevance-based search service across multiple Dataverse tables, powered by Azure Cognitive Search.',
 ARRAY['dataverse','search','full-text','pl-400'], 'teacher_john', 'teacher_john'),

('concept_pp_virtualcol01', 'Virtual Column',
 'software',
 'A Dataverse column that retrieves its value from an external data source at query time without storing data in Dataverse.',
 ARRAY['dataverse','column','virtual','pl-400'], 'teacher_john', 'teacher_john'),

('concept_pp_choice01', 'Choice Column',
 'software',
 'A Dataverse column type (formerly Option Set) that stores a value from a predefined list of integer-label pairs.',
 ARRAY['dataverse','column','option-set','pl-400'], 'teacher_john', 'teacher_john'),

('concept_pp_polylookup01', 'Polymorphic Lookup',
 'software',
 'A Lookup column in Dataverse that can reference rows from more than one table type (e.g. Customer lookup to Account or Contact).',
 ARRAY['dataverse','relationship','lookup','pl-400'], 'teacher_john', 'teacher_john'),

('concept_pp_tableperm01', 'Table Permission',
 'software',
 'A Power Pages security construct that grants website users access to Dataverse table rows based on scope (Global, Contact, Account, etc.).',
 ARRAY['power-pages','security','dataverse','pl-400'], 'teacher_john', 'teacher_john'),

-- ── Group 3: Power Apps Development ──────────────────────────────────────────
('concept_pp_canvasapp01', 'Canvas App',
 'software',
 'A Power Apps application built on a blank canvas where developers control every UI element, layout, and behavior using Power Fx formulas.',
 ARRAY['power-apps','canvas','pl-400'], 'teacher_john', 'teacher_john'),

('concept_pp_mdapp01', 'Model-Driven App',
 'software',
 'A Power Apps application generated from Dataverse metadata, automatically rendering forms, views, charts, and dashboards.',
 ARRAY['power-apps','model-driven','dataverse','pl-400'], 'teacher_john', 'teacher_john'),

('concept_pp_powerfx01', 'Power Fx Formula',
 'software',
 'The low-code formula language used in Canvas Apps, inspired by Excel, for defining logic, data operations, and navigation.',
 ARRAY['power-apps','power-fx','formula','pl-400'], 'teacher_john', 'teacher_john'),

('concept_pp_connector01', 'Connector',
 'software',
 'A proxy wrapper around an external API that Power Apps and Power Automate use to communicate with services like SharePoint, SQL, or custom APIs.',
 ARRAY['power-apps','connector','integration','pl-400'], 'teacher_john', 'teacher_john'),

('concept_pp_delegation01', 'Delegation',
 'software',
 'The ability for a Canvas App data function to push query processing to the data source rather than downloading all records locally, avoiding the row limit.',
 ARRAY['power-apps','performance','data','pl-400'], 'teacher_john', 'teacher_john'),

('concept_pp_collection01', 'Collection',
 'software',
 'An in-memory table stored locally in a Canvas App, created with Collect() or ClearCollect(), used for caching or staging data.',
 ARRAY['power-apps','canvas','data','pl-400'], 'teacher_john', 'teacher_john'),

('concept_pp_gallery01', 'Gallery Control',
 'software',
 'A Canvas App control that displays a scrollable list of records where each item shares the same layout template.',
 ARRAY['power-apps','canvas','ui','pl-400'], 'teacher_john', 'teacher_john'),

('concept_pp_appform01', 'App Form Control',
 'software',
 'A Canvas or Model-Driven App control for displaying and editing a single Dataverse row, supporting Edit, View, and New modes.',
 ARRAY['power-apps','form','dataverse','pl-400'], 'teacher_john', 'teacher_john'),

('concept_pp_custompage01', 'Custom Page',
 'software',
 'A Canvas App page embedded inside a Model-Driven App, enabling rich custom UI while retaining access to Dataverse context.',
 ARRAY['power-apps','model-driven','canvas','pl-400'], 'teacher_john', 'teacher_john'),

('concept_pp_appdesigner01', 'App Designer',
 'software',
 'The visual tool in the Power Apps maker portal for configuring a Model-Driven App''s navigation, forms, views, and dashboards.',
 ARRAY['power-apps','model-driven','tooling','pl-400'], 'teacher_john', 'teacher_john'),

-- ── Group 4: PCF and Client Scripting ────────────────────────────────────────
('concept_pp_pcf01', 'Power Apps Component Framework (PCF)',
 'software',
 'A framework for building reusable code components using TypeScript and standard web technologies that run inside Canvas or Model-Driven Apps.',
 ARRAY['pcf','power-apps','typescript','pl-400'], 'teacher_john', 'teacher_john'),

('concept_pp_typescript01', 'TypeScript in PCF',
 'software',
 'PCF components are authored in TypeScript; the framework provides a strongly-typed manifest and lifecycle interface (init, updateView, destroy).',
 ARRAY['pcf','typescript','development','pl-400'], 'teacher_john', 'teacher_john'),

('concept_pp_reactpcf01', 'React Virtual PCF Control',
 'software',
 'A PCF control type that renders through a shared React root managed by Power Apps, improving performance by avoiding per-control React instances.',
 ARRAY['pcf','react','virtual','pl-400'], 'teacher_john', 'teacher_john'),

('concept_pp_pcfmanifest01', 'PCF Manifest',
 'software',
 'The ControlManifest.Input.xml file that declares a PCF component''s properties, resources, and feature usage to the Power Apps runtime.',
 ARRAY['pcf','manifest','configuration','pl-400'], 'teacher_john', 'teacher_john'),

('concept_pp_xrm01', 'Client API (Xrm)',
 'software',
 'The JavaScript object model (window.Xrm) available in Model-Driven Apps for manipulating forms, fields, tabs, and navigating records.',
 ARRAY['client-api','xrm','javascript','pl-400'], 'teacher_john', 'teacher_john'),

('concept_pp_formevent01', 'Form Event',
 'software',
 'Events fired during the Model-Driven App form lifecycle: OnLoad, OnSave, and OnChange, to which JavaScript handlers can be registered.',
 ARRAY['client-api','form','events','pl-400'], 'teacher_john', 'teacher_john'),

('concept_pp_fieldevent01', 'Field (Column) Event',
 'software',
 'OnChange event on a Model-Driven App form field that fires when a user changes the field value, used for field-level business logic.',
 ARRAY['client-api','field','events','pl-400'], 'teacher_john', 'teacher_john'),

('concept_pp_jswebres01', 'JavaScript Web Resource',
 'software',
 'A .js file stored in Dataverse as a web resource and referenced by form event handlers or ribbon commands in Model-Driven Apps.',
 ARRAY['web-resource','javascript','model-driven','pl-400'], 'teacher_john', 'teacher_john'),

('concept_pp_htmlwebres01', 'HTML Web Resource',
 'software',
 'A .html file stored as a Dataverse web resource, embeddable as an iframe inside a Model-Driven App form for fully custom UI.',
 ARRAY['web-resource','html','model-driven','pl-400'], 'teacher_john', 'teacher_john'),

('concept_pp_commandbar01', 'Command Bar Customization',
 'software',
 'Customizing the ribbon/command bar buttons in Model-Driven Apps using the modern Command Designer or classic Ribbon Workbench.',
 ARRAY['model-driven','ribbon','command','pl-400'], 'teacher_john', 'teacher_john'),

-- ── Group 5: Power Automate Fundamentals ─────────────────────────────────────
('concept_pp_cloudflow01', 'Cloud Flow',
 'software',
 'A Power Automate automation that runs in the cloud, connecting services via triggers and actions without requiring local infrastructure.',
 ARRAY['power-automate','flow','automation','pl-400'], 'teacher_john', 'teacher_john'),

('concept_pp_flowtrigger01', 'Flow Trigger',
 'software',
 'The event that starts a Cloud Flow, such as when a Dataverse row is created, a schedule fires, or an HTTP request is received.',
 ARRAY['power-automate','trigger','event','pl-400'], 'teacher_john', 'teacher_john'),

('concept_pp_flowaction01', 'Flow Action',
 'software',
 'A unit of work in a Cloud Flow that performs an operation, such as sending an email, updating a Dataverse row, or calling an HTTP endpoint.',
 ARRAY['power-automate','action','step','pl-400'], 'teacher_john', 'teacher_john'),

('concept_pp_condition01', 'Condition',
 'software',
 'A Power Automate control action that branches flow execution into "If yes" and "If no" paths based on a boolean expression.',
 ARRAY['power-automate','logic','branching','pl-400'], 'teacher_john', 'teacher_john'),

('concept_pp_applytoeach01', 'Apply to Each',
 'software',
 'A Power Automate loop control that iterates over each item in an array, executing nested actions for every element.',
 ARRAY['power-automate','loop','array','pl-400'], 'teacher_john', 'teacher_john'),

('concept_pp_errorhandling01', 'Flow Error Handling',
 'software',
 'Using Scope actions with "Configure run after" settings (failed, skipped, timed out) to implement try/catch patterns in Cloud Flows.',
 ARRAY['power-automate','error-handling','resilience','pl-400'], 'teacher_john', 'teacher_john'),

('concept_pp_envvar01', 'Environment Variable',
 'software',
 'A solution component that stores configuration values (strings, numbers, JSON, secrets) separately from flow logic, enabling environment-specific settings.',
 ARRAY['power-automate','alm','configuration','pl-400'], 'teacher_john', 'teacher_john'),

('concept_pp_connref01', 'Connection Reference',
 'software',
 'A solution component that abstracts the connection used by a connector, allowing credentials to be swapped per environment without editing the flow.',
 ARRAY['power-automate','alm','connector','pl-400'], 'teacher_john', 'teacher_john'),

('concept_pp_approval01', 'Approval Flow',
 'software',
 'A Power Automate pattern using the Approvals connector to route items for human review, collecting approve/reject responses before continuing.',
 ARRAY['power-automate','approval','human-in-loop','pl-400'], 'teacher_john', 'teacher_john'),

('concept_pp_childflow01', 'Child Flow',
 'software',
 'A Cloud Flow called from another flow using the "Run a Child Flow" action, enabling reusable flow logic shared across multiple parent flows.',
 ARRAY['power-automate','reuse','modular','pl-400'], 'teacher_john', 'teacher_john'),

-- ── Group 6: Business Process Automation ─────────────────────────────────────
('concept_pp_bpf01', 'Business Process Flow',
 'software',
 'A guided, stage-based process overlay in Model-Driven Apps that walks users through required steps to complete a business process.',
 ARRAY['power-automate','bpf','process','pl-400'], 'teacher_john', 'teacher_john'),

('concept_pp_bpfstage01', 'BPF Stage',
 'software',
 'A named phase in a Business Process Flow containing data steps (fields) the user must complete before advancing to the next stage.',
 ARRAY['bpf','stage','process','pl-400'], 'teacher_john', 'teacher_john'),

('concept_pp_bizrule01', 'Business Rule',
 'software',
 'A no-code rule configured on a Dataverse table that enforces field requirements, visibility, or default values on forms and server-side.',
 ARRAY['dataverse','business-rule','no-code','pl-400'], 'teacher_john', 'teacher_john'),

('concept_pp_custaction01', 'Custom Process Action',
 'software',
 'A reusable, named Dataverse operation that can be called from flows, plugins, or client scripts, similar to a lightweight custom API.',
 ARRAY['dataverse','process','reuse','pl-400'], 'teacher_john', 'teacher_john'),

('concept_pp_customapi01', 'Custom API',
 'software',
 'A Dataverse extension point that exposes a custom message callable via the Web API, backed by a plugin, with defined request/response parameters.',
 ARRAY['dataverse','api','plugin','pl-400'], 'teacher_john', 'teacher_john'),

('concept_pp_scheduledflow01', 'Scheduled Flow',
 'software',
 'A Cloud Flow triggered on a recurring schedule (every X minutes/hours/days), used for batch processing or periodic data synchronization.',
 ARRAY['power-automate','schedule','batch','pl-400'], 'teacher_john', 'teacher_john'),

('concept_pp_automatedflow01', 'Automated Flow',
 'software',
 'A Cloud Flow triggered automatically by an event in a connected service, such as a new Dataverse row or an incoming email.',
 ARRAY['power-automate','automated','event','pl-400'], 'teacher_john', 'teacher_john'),

('concept_pp_instantflow01', 'Instant Flow',
 'software',
 'A Cloud Flow triggered manually by a user from the Power Automate app, a Power Apps button, or a Teams message action.',
 ARRAY['power-automate','manual','button','pl-400'], 'teacher_john', 'teacher_john'),

('concept_pp_desktopflow01', 'Desktop Flow (RPA)',
 'software',
 'A Power Automate automation that runs on a local machine to automate legacy or desktop applications through UI interaction (Robotic Process Automation).',
 ARRAY['power-automate','rpa','desktop','pl-400'], 'teacher_john', 'teacher_john'),

('concept_pp_classicwf01', 'Classic Workflow',
 'software',
 'A legacy Dataverse automation (background/real-time process) that predates Power Automate; still supported but recommended to migrate to Cloud Flows.',
 ARRAY['dataverse','workflow','legacy','pl-400'], 'teacher_john', 'teacher_john'),

-- ── Group 7: Plugin Development ───────────────────────────────────────────────
('concept_pp_plugin01', 'Plugin',
 'software',
 'A .NET assembly containing event-handler classes that execute synchronously or asynchronously in response to Dataverse data operations.',
 ARRAY['plugin','dataverse','dotnet','pl-400'], 'teacher_john', 'teacher_john'),

('concept_pp_pluginstep01', 'Plugin Step',
 'software',
 'The registration of a plugin class against a specific Dataverse message (e.g. Create, Update) and table at a chosen pipeline stage (Pre/Post-Operation).',
 ARRAY['plugin','registration','step','pl-400'], 'teacher_john', 'teacher_john'),

('concept_pp_pluginimage01', 'Plugin Image',
 'software',
 'A snapshot of a Dataverse row''s column values captured before (Pre-Image) or after (Post-Image) an operation, available to the plugin for comparison.',
 ARRAY['plugin','image','snapshot','pl-400'], 'teacher_john', 'teacher_john'),

('concept_pp_iorgservice01', 'IOrganizationService',
 'software',
 'The primary Dataverse service interface in a plugin, used to execute CRUD operations, queries, and custom messages against Dataverse.',
 ARRAY['plugin','service','api','pl-400'], 'teacher_john', 'teacher_john'),

('concept_pp_ipluginctx01', 'IPluginExecutionContext',
 'software',
 'The interface providing a plugin with information about the triggering event: input/output parameters, pre/post images, user IDs, and call depth.',
 ARRAY['plugin','context','execution','pl-400'], 'teacher_john', 'teacher_john'),

('concept_pp_svccontext01', 'OrganizationServiceContext',
 'software',
 'A LINQ-enabled proxy that wraps IOrganizationService, enabling strongly-typed entity queries and change tracking in plugin or custom code.',
 ARRAY['plugin','linq','service','pl-400'], 'teacher_john', 'teacher_john'),

('concept_pp_virtualtable01', 'Virtual Table Provider',
 'software',
 'A plugin-based provider that maps an external data source into a Dataverse virtual table, enabling CRUD operations on external data via the standard API.',
 ARRAY['plugin','virtual-table','integration','pl-400'], 'teacher_john', 'teacher_john'),

('concept_pp_asyncplugin01', 'Asynchronous Plugin',
 'software',
 'A plugin step registered to run asynchronously after the transaction commits via the Async Service, not blocking the synchronous user operation.',
 ARRAY['plugin','async','performance','pl-400'], 'teacher_john', 'teacher_john'),

('concept_pp_plugintrace01', 'Plugin Trace Log',
 'software',
 'A Dataverse feature that captures ITracingService output from plugins, written to the PluginTraceLog table for debugging failures.',
 ARRAY['plugin','debugging','trace','pl-400'], 'teacher_john', 'teacher_john'),

('concept_pp_sandbox01', 'Plugin Sandbox Mode',
 'software',
 'The isolated execution environment for plugins that restricts access to network, file system, and registry, enforcing security and stability.',
 ARRAY['plugin','sandbox','security','pl-400'], 'teacher_john', 'teacher_john'),

-- ── Group 8: Integration and APIs ────────────────────────────────────────────
('concept_pp_webapi01', 'Dataverse Web API',
 'software',
 'A RESTful API following the OData v4 standard that provides full CRUD, query, and custom message access to Dataverse data and metadata.',
 ARRAY['web-api','rest','odata','pl-400'], 'teacher_john', 'teacher_john'),

('concept_pp_odata01', 'OData Query Syntax',
 'software',
 'Standard URL query options ($filter, $select, $expand, $orderby, $top) used with the Dataverse Web API to retrieve and shape data.',
 ARRAY['odata','web-api','query','pl-400'], 'teacher_john', 'teacher_john'),

('concept_pp_customconn01', 'Custom Connector',
 'software',
 'A user-defined connector built from an OpenAPI definition that wraps any HTTP API for use in Power Apps and Power Automate.',
 ARRAY['connector','custom','openapi','pl-400'], 'teacher_john', 'teacher_john'),

('concept_pp_openapi01', 'OpenAPI Definition',
 'software',
 'A machine-readable specification (Swagger/OpenAPI 2.0) that describes an API''s endpoints, parameters, and authentication for custom connectors.',
 ARRAY['openapi','swagger','api','pl-400'], 'teacher_john', 'teacher_john'),

('concept_pp_webhook01', 'Webhook',
 'software',
 'A Dataverse service endpoint type that sends an HTTP POST to an external URL when a registered Dataverse event occurs.',
 ARRAY['webhook','integration','event','pl-400'], 'teacher_john', 'teacher_john'),

('concept_pp_svcendpoint01', 'Service Endpoint',
 'software',
 'A Dataverse configuration that routes event messages to Azure Service Bus, Azure Event Hub, or a Webhook target for external integration.',
 ARRAY['service-endpoint','azure','integration','pl-400'], 'teacher_john', 'teacher_john'),

('concept_pp_servicebus01', 'Azure Service Bus Integration',
 'software',
 'Dataverse can post event context messages to an Azure Service Bus queue or topic, enabling decoupled, async integration with external systems.',
 ARRAY['azure-service-bus','integration','async','pl-400'], 'teacher_john', 'teacher_john'),

('concept_pp_oauth201', 'OAuth 2.0',
 'software',
 'The authorization protocol used by Power Platform to authenticate connectors and custom APIs, using client credentials or authorization code flows.',
 ARRAY['oauth','security','authentication','pl-400'], 'teacher_john', 'teacher_john'),

('concept_pp_powerbi01', 'Power BI Embedded',
 'software',
 'Integration that embeds Power BI reports and dashboards inside Model-Driven App dashboards or forms for in-context analytics.',
 ARRAY['power-bi','analytics','model-driven','pl-400'], 'teacher_john', 'teacher_john'),

('concept_pp_powerpages01', 'Power Pages',
 'software',
 'A low-code platform for building externally-facing websites backed by Dataverse, with built-in authentication and Table Permissions.',
 ARRAY['power-pages','portal','web','pl-400'], 'teacher_john', 'teacher_john'),

-- ── Group 9: ALM and DevOps ───────────────────────────────────────────────────
('concept_pp_alm01', 'Application Lifecycle Management (ALM)',
 'software',
 'The practice of managing Power Platform solutions across Development, Test, and Production environments using automated pipelines and source control.',
 ARRAY['alm','devops','deployment','pl-400'], 'teacher_john', 'teacher_john'),

('concept_pp_solchecker01', 'Solution Checker',
 'software',
 'A Power Platform tool that performs static analysis of solution components against a ruleset to identify performance, reliability, and upgrade issues.',
 ARRAY['alm','quality','static-analysis','pl-400'], 'teacher_john', 'teacher_john'),

('concept_pp_ppcli01', 'Power Platform CLI (pac)',
 'software',
 'A cross-platform command-line tool for automating Power Platform tasks: exporting/importing solutions, managing environments, and scaffolding PCF projects.',
 ARRAY['cli','devops','pac','pl-400'], 'teacher_john', 'teacher_john'),

('concept_pp_azdevops01', 'Azure DevOps for Power Platform',
 'software',
 'Using Azure DevOps pipelines with the Power Platform Build Tools extension to automate solution export, check, import, and release across environments.',
 ARRAY['azure-devops','alm','pipeline','pl-400'], 'teacher_john', 'teacher_john'),

('concept_pp_ghactions01', 'GitHub Actions for Power Platform',
 'software',
 'A set of GitHub Actions (microsoft/powerplatform-actions) that automate solution packaging, publishing, and environment management in GitHub CI/CD workflows.',
 ARRAY['github-actions','alm','ci-cd','pl-400'], 'teacher_john', 'teacher_john'),

('concept_pp_envstrategy01', 'Environment Strategy',
 'software',
 'Planning and structuring Power Platform environments (Development, Sandbox, UAT, Production) to support team collaboration and safe deployments.',
 ARRAY['environment','alm','governance','pl-400'], 'teacher_john', 'teacher_john'),

('concept_pp_managedenv01', 'Managed Environment',
 'software',
 'A premium Power Platform feature enabling enhanced governance: weekly digest, usage insights, solution checker enforcement, and sharing limits.',
 ARRAY['environment','governance','admin','pl-400'], 'teacher_john', 'teacher_john'),

('concept_pp_sollayers01', 'Solution Layers',
 'software',
 'The stacked customization model in Dataverse where each solution adds a layer on top of base components; the active layer is the merged result.',
 ARRAY['solution','layers','customization','pl-400'], 'teacher_john', 'teacher_john'),

('concept_pp_depcheck01', 'Dependency Checker',
 'software',
 'A Dataverse tool that identifies components that depend on or are required by a given solution component, preventing accidental deletion.',
 ARRAY['solution','dependency','alm','pl-400'], 'teacher_john', 'teacher_john'),

('concept_pp_fieldsecp01', 'Field Security Profile',
 'software',
 'A Dataverse security construct that restricts which users or teams can read, create, or update specific sensitive columns on a table.',
 ARRAY['security','field','dataverse','pl-400'], 'teacher_john', 'teacher_john'),

-- ── Group 10: Security and Governance ────────────────────────────────────────
('concept_pp_dlp01', 'Data Loss Prevention (DLP) Policy',
 'software',
 'An admin-configured policy that classifies connectors into Business, Non-Business, or Blocked tiers to prevent unauthorized data exfiltration in flows.',
 ARRAY['dlp','governance','security','pl-400'], 'teacher_john', 'teacher_john'),

('concept_pp_admincenter01', 'Power Platform Admin Center',
 'software',
 'The web portal for managing environments, capacity, DLP policies, connectors, and tenant-level analytics across the Power Platform tenant.',
 ARRAY['admin','governance','portal','pl-400'], 'teacher_john', 'teacher_john'),

('concept_pp_coe01', 'Center of Excellence (CoE) Toolkit',
 'software',
 'A reference implementation of governance tooling deployed to a Power Platform environment to gain visibility, drive adoption, and enforce standards.',
 ARRAY['coe','governance','toolkit','pl-400'], 'teacher_john', 'teacher_john'),

('concept_pp_tenantanalytics01', 'Tenant-level Analytics',
 'software',
 'Admin Center reports showing usage metrics across all environments: active users, flow runs, connector usage, and app launches at the tenant level.',
 ARRAY['analytics','governance','admin','pl-400'], 'teacher_john', 'teacher_john'),

('concept_pp_managedid01', 'Managed Identity Authentication',
 'software',
 'Using Azure-managed identities (system-assigned or user-assigned) for Power Platform connectors and Azure resources to avoid storing credentials.',
 ARRAY['security','managed-identity','azure','pl-400'], 'teacher_john', 'teacher_john'),

('concept_pp_apilimit01', 'API Request Limits',
 'software',
 'Per-user, per-day limits on Dataverse and connector API calls in Power Platform, with capacity add-ons available for high-volume workloads.',
 ARRAY['licensing','limits','capacity','pl-400'], 'teacher_john', 'teacher_john'),

('concept_pp_licensing01', 'Power Platform Licensing',
 'software',
 'The licensing model covering per-app, per-user, and pay-as-you-go plans for Power Apps, plus premium connector and Dataverse capacity entitlements.',
 ARRAY['licensing','admin','governance','pl-400'], 'teacher_john', 'teacher_john'),

('concept_pp_dvteam01', 'Dataverse Team',
 'software',
 'A group of users in Dataverse (Owner, Access, or AAD Group team) that can be assigned security roles, simplifying bulk permission management.',
 ARRAY['security','team','dataverse','pl-400'], 'teacher_john', 'teacher_john'),

('concept_pp_hierarchysec01', 'Hierarchy Security',
 'software',
 'A Dataverse security model (Manager or Position hierarchy) that grants managers read or write access to their direct and indirect reports'' records.',
 ARRAY['security','hierarchy','dataverse','pl-400'], 'teacher_john', 'teacher_john'),

('concept_pp_pad01', 'Power Automate Desktop (PAD)',
 'software',
 'The desktop application for building and running Desktop Flows locally, with a drag-and-drop designer and hundreds of built-in UI automation actions.',
 ARRAY['power-automate','desktop','rpa','pl-400'], 'teacher_john', 'teacher_john')

ON CONFLICT (id) DO NOTHING;

-- ---------------------------------------------------------------------------
-- Topics (10, one per group)
-- ---------------------------------------------------------------------------

INSERT INTO topics (id, name, folder_id, description, created_by, updated_by)
VALUES
    ('topic_pp_dvfund01', 'Dataverse Fundamentals',
     'folder_powerplatform01',
     'Core Dataverse concepts: tables, columns, relationships, solutions, publishers, and security roles.',
     'teacher_john', 'teacher_john'),

    ('topic_pp_dvadvanced01', 'Dataverse Advanced Features',
     'folder_powerplatform01',
     'Advanced Dataverse features: calculated/rollup columns, alternate keys, elastic tables, virtual columns, audit logs, and search.',
     'teacher_john', 'teacher_john'),

    ('topic_pp_powerapps01', 'Power Apps Development',
     'folder_powerplatform01',
     'Building Canvas and Model-Driven Apps: Power Fx, connectors, delegation, collections, galleries, and app design.',
     'teacher_john', 'teacher_john'),

    ('topic_pp_pcfclient01', 'PCF and Client Scripting',
     'folder_powerplatform01',
     'Extending the UI with PCF controls, TypeScript, React, Client API (Xrm), web resources, and command bar customization.',
     'teacher_john', 'teacher_john'),

    ('topic_pp_autofund01', 'Power Automate Fundamentals',
     'folder_powerplatform01',
     'Core Cloud Flow concepts: triggers, actions, conditions, loops, error handling, environment variables, and connection references.',
     'teacher_john', 'teacher_john'),

    ('topic_pp_bizauto01', 'Business Process Automation',
     'folder_powerplatform01',
     'Business Process Flows, business rules, custom actions, custom APIs, and the full range of flow types (scheduled, automated, instant, desktop, classic).',
     'teacher_john', 'teacher_john'),

    ('topic_pp_plugindev01', 'Plugin Development',
     'folder_powerplatform01',
     'Writing .NET plugins: steps, images, IOrganizationService, IPluginExecutionContext, async plugins, trace logs, and sandbox mode.',
     'teacher_john', 'teacher_john'),

    ('topic_pp_integration01', 'Integration and APIs',
     'folder_powerplatform01',
     'Integrating Power Platform via Web API, OData, custom connectors, OpenAPI, webhooks, service endpoints, Azure Service Bus, OAuth, Power BI, and Power Pages.',
     'teacher_john', 'teacher_john'),

    ('topic_pp_alm01', 'ALM and DevOps',
     'folder_powerplatform01',
     'Application lifecycle management: Solution Checker, pac CLI, Azure DevOps, GitHub Actions, environment strategy, solution layers, and field security profiles.',
     'teacher_john', 'teacher_john'),

    ('topic_pp_secgov01', 'Security and Governance',
     'folder_powerplatform01',
     'DLP policies, Admin Center, CoE Toolkit, tenant analytics, managed identities, API limits, licensing, Dataverse teams, and hierarchy security.',
     'teacher_john', 'teacher_john')
ON CONFLICT (id) DO NOTHING;

-- ---------------------------------------------------------------------------
-- Topic ↔ Concept mappings (10 concepts per topic = 100 total)
-- ---------------------------------------------------------------------------

INSERT INTO topic_concepts (topic_id, concept_id)
VALUES
    -- Dataverse Fundamentals
    ('topic_pp_dvfund01', 'concept_pp_dataverse01'),
    ('topic_pp_dvfund01', 'concept_pp_table01'),
    ('topic_pp_dvfund01', 'concept_pp_columntype01'),
    ('topic_pp_dvfund01', 'concept_pp_onetomany01'),
    ('topic_pp_dvfund01', 'concept_pp_manytomany01'),
    ('topic_pp_dvfund01', 'concept_pp_solution01'),
    ('topic_pp_dvfund01', 'concept_pp_publisher01'),
    ('topic_pp_dvfund01', 'concept_pp_managed01'),
    ('topic_pp_dvfund01', 'concept_pp_securityrole01'),
    ('topic_pp_dvfund01', 'concept_pp_businessunit01'),
    -- Dataverse Advanced Features
    ('topic_pp_dvadvanced01', 'concept_pp_calculated01'),
    ('topic_pp_dvadvanced01', 'concept_pp_rollup01'),
    ('topic_pp_dvadvanced01', 'concept_pp_altkey01'),
    ('topic_pp_dvadvanced01', 'concept_pp_elastictable01'),
    ('topic_pp_dvadvanced01', 'concept_pp_auditlog01'),
    ('topic_pp_dvadvanced01', 'concept_pp_dvsearch01'),
    ('topic_pp_dvadvanced01', 'concept_pp_virtualcol01'),
    ('topic_pp_dvadvanced01', 'concept_pp_choice01'),
    ('topic_pp_dvadvanced01', 'concept_pp_polylookup01'),
    ('topic_pp_dvadvanced01', 'concept_pp_tableperm01'),
    -- Power Apps Development
    ('topic_pp_powerapps01', 'concept_pp_canvasapp01'),
    ('topic_pp_powerapps01', 'concept_pp_mdapp01'),
    ('topic_pp_powerapps01', 'concept_pp_powerfx01'),
    ('topic_pp_powerapps01', 'concept_pp_connector01'),
    ('topic_pp_powerapps01', 'concept_pp_delegation01'),
    ('topic_pp_powerapps01', 'concept_pp_collection01'),
    ('topic_pp_powerapps01', 'concept_pp_gallery01'),
    ('topic_pp_powerapps01', 'concept_pp_appform01'),
    ('topic_pp_powerapps01', 'concept_pp_custompage01'),
    ('topic_pp_powerapps01', 'concept_pp_appdesigner01'),
    -- PCF and Client Scripting
    ('topic_pp_pcfclient01', 'concept_pp_pcf01'),
    ('topic_pp_pcfclient01', 'concept_pp_typescript01'),
    ('topic_pp_pcfclient01', 'concept_pp_reactpcf01'),
    ('topic_pp_pcfclient01', 'concept_pp_pcfmanifest01'),
    ('topic_pp_pcfclient01', 'concept_pp_xrm01'),
    ('topic_pp_pcfclient01', 'concept_pp_formevent01'),
    ('topic_pp_pcfclient01', 'concept_pp_fieldevent01'),
    ('topic_pp_pcfclient01', 'concept_pp_jswebres01'),
    ('topic_pp_pcfclient01', 'concept_pp_htmlwebres01'),
    ('topic_pp_pcfclient01', 'concept_pp_commandbar01'),
    -- Power Automate Fundamentals
    ('topic_pp_autofund01', 'concept_pp_cloudflow01'),
    ('topic_pp_autofund01', 'concept_pp_flowtrigger01'),
    ('topic_pp_autofund01', 'concept_pp_flowaction01'),
    ('topic_pp_autofund01', 'concept_pp_condition01'),
    ('topic_pp_autofund01', 'concept_pp_applytoeach01'),
    ('topic_pp_autofund01', 'concept_pp_errorhandling01'),
    ('topic_pp_autofund01', 'concept_pp_envvar01'),
    ('topic_pp_autofund01', 'concept_pp_connref01'),
    ('topic_pp_autofund01', 'concept_pp_approval01'),
    ('topic_pp_autofund01', 'concept_pp_childflow01'),
    -- Business Process Automation
    ('topic_pp_bizauto01', 'concept_pp_bpf01'),
    ('topic_pp_bizauto01', 'concept_pp_bpfstage01'),
    ('topic_pp_bizauto01', 'concept_pp_bizrule01'),
    ('topic_pp_bizauto01', 'concept_pp_custaction01'),
    ('topic_pp_bizauto01', 'concept_pp_customapi01'),
    ('topic_pp_bizauto01', 'concept_pp_scheduledflow01'),
    ('topic_pp_bizauto01', 'concept_pp_automatedflow01'),
    ('topic_pp_bizauto01', 'concept_pp_instantflow01'),
    ('topic_pp_bizauto01', 'concept_pp_desktopflow01'),
    ('topic_pp_bizauto01', 'concept_pp_classicwf01'),
    -- Plugin Development
    ('topic_pp_plugindev01', 'concept_pp_plugin01'),
    ('topic_pp_plugindev01', 'concept_pp_pluginstep01'),
    ('topic_pp_plugindev01', 'concept_pp_pluginimage01'),
    ('topic_pp_plugindev01', 'concept_pp_iorgservice01'),
    ('topic_pp_plugindev01', 'concept_pp_ipluginctx01'),
    ('topic_pp_plugindev01', 'concept_pp_svccontext01'),
    ('topic_pp_plugindev01', 'concept_pp_virtualtable01'),
    ('topic_pp_plugindev01', 'concept_pp_asyncplugin01'),
    ('topic_pp_plugindev01', 'concept_pp_plugintrace01'),
    ('topic_pp_plugindev01', 'concept_pp_sandbox01'),
    -- Integration and APIs
    ('topic_pp_integration01', 'concept_pp_webapi01'),
    ('topic_pp_integration01', 'concept_pp_odata01'),
    ('topic_pp_integration01', 'concept_pp_customconn01'),
    ('topic_pp_integration01', 'concept_pp_openapi01'),
    ('topic_pp_integration01', 'concept_pp_webhook01'),
    ('topic_pp_integration01', 'concept_pp_svcendpoint01'),
    ('topic_pp_integration01', 'concept_pp_servicebus01'),
    ('topic_pp_integration01', 'concept_pp_oauth201'),
    ('topic_pp_integration01', 'concept_pp_powerbi01'),
    ('topic_pp_integration01', 'concept_pp_powerpages01'),
    -- ALM and DevOps
    ('topic_pp_alm01', 'concept_pp_alm01'),
    ('topic_pp_alm01', 'concept_pp_solchecker01'),
    ('topic_pp_alm01', 'concept_pp_ppcli01'),
    ('topic_pp_alm01', 'concept_pp_azdevops01'),
    ('topic_pp_alm01', 'concept_pp_ghactions01'),
    ('topic_pp_alm01', 'concept_pp_envstrategy01'),
    ('topic_pp_alm01', 'concept_pp_managedenv01'),
    ('topic_pp_alm01', 'concept_pp_sollayers01'),
    ('topic_pp_alm01', 'concept_pp_depcheck01'),
    ('topic_pp_alm01', 'concept_pp_fieldsecp01'),
    -- Security and Governance
    ('topic_pp_secgov01', 'concept_pp_dlp01'),
    ('topic_pp_secgov01', 'concept_pp_admincenter01'),
    ('topic_pp_secgov01', 'concept_pp_coe01'),
    ('topic_pp_secgov01', 'concept_pp_tenantanalytics01'),
    ('topic_pp_secgov01', 'concept_pp_managedid01'),
    ('topic_pp_secgov01', 'concept_pp_apilimit01'),
    ('topic_pp_secgov01', 'concept_pp_licensing01'),
    ('topic_pp_secgov01', 'concept_pp_dvteam01'),
    ('topic_pp_secgov01', 'concept_pp_hierarchysec01'),
    ('topic_pp_secgov01', 'concept_pp_pad01')
ON CONFLICT (topic_id, concept_id) DO NOTHING;
