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
INSERT INTO topic_concepts (topic_id, concept_id, position)
VALUES
    ('topic_emailstruct01', 'concept_subjectline01', 0),
    ('topic_emailstruct01', 'concept_salutation01',  1),
    ('topic_emailtone001',  'concept_tone001',        0),
    ('topic_emailtone001',  'concept_cta001',         1),
    ('topic_basiclaws001',  'concept_voltage001',     0),
    ('topic_basiclaws001',  'concept_resistance01',   1),
    ('topic_basiclaws001',  'concept_ohmslaw001',     2),
    ('topic_circuittypes01','concept_current001',     0),
    ('topic_circuittypes01','concept_voltage001',     1)
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
