# Schema (v2)

---

## 1️⃣ Collection

Collection (
id              UUID PRIMARY KEY,
owner_id        UUID REFERENCES User(id) NOT NULL,   -- user ownership
name            TEXT NOT NULL,
description     TEXT,
created_at      TIMESTAMP NOT NULL DEFAULT now(),
updated_at      TIMESTAMP NOT NULL DEFAULT now()
)

👉 Example: "Electronics", "Robotics"

---

## 2️⃣ Source (raw content)

Source (
id              UUID PRIMARY KEY,
collection_id   UUID REFERENCES Collection(id),

source_type     TEXT NOT NULL CHECK (source_type IN ('uploaded_file', 'text', 'url')),
type            TEXT CHECK (type IN ('pdf', 'audio', 'video', 'article')),
title           TEXT,
file_url        TEXT,          -- populated when source_type = 'uploaded_file'
content         TEXT,          -- populated when source_type = 'text' or extracted text

created_at      TIMESTAMP NOT NULL DEFAULT now(),
updated_at      TIMESTAMP NOT NULL DEFAULT now()
)

👉 One source = one uploaded item (PDF, audio, etc.) or extracted text

---

## 3️⃣ Topic (structure layer)

Topic (
id              UUID PRIMARY KEY,
name            TEXT NOT NULL,
description     TEXT
)

Mapping (many-to-many):

SourceTopic (
source_id       UUID REFERENCES Source(id),
topic_id        UUID REFERENCES Topic(id),
PRIMARY KEY (source_id, topic_id)
)

👉 Topics are reusable across sources

---

## 4️⃣ Concept (core of system)

Concept (
id              UUID PRIMARY KEY,
name            TEXT NOT NULL,
description     TEXT,

embedding       VECTOR,        -- for similarity search (optional early)

created_at      TIMESTAMP NOT NULL DEFAULT now(),
updated_at      TIMESTAMP NOT NULL DEFAULT now()
)

Aliases (for deduplication):

ConceptAlias (
concept_id      UUID REFERENCES Concept(id),
alias           TEXT NOT NULL,
PRIMARY KEY (concept_id, alias)   -- alias itself is the natural key, no surrogate id
)

Relations (graph):

ConceptRelation (
source_id       UUID REFERENCES Concept(id),   -- the "from" concept
target_id       UUID REFERENCES Concept(id),   -- the "to" concept
                                               -- direction matters: source→target
                                               -- e.g. "Ohm's Law" prerequisite→ "Circuit Analysis"
relation_type   TEXT CHECK (relation_type IN ('prerequisite', 'part_of', 'related_to')),

PRIMARY KEY (source_id, target_id, relation_type)
)

---

## 5️⃣ Space (content container)

Space groups learning content under a concept. Each space has a type that
determines what kind of content it holds.

Space (
id              UUID PRIMARY KEY,
concept_id      UUID REFERENCES Concept(id),
source_id       UUID REFERENCES Source(id),    -- provenance: which source generated this space

space_type      TEXT CHECK (space_type IN ('lesson', 'quiz', 'flashcard', 'problem')),
name            TEXT,
description     TEXT,

difficulty      TEXT CHECK (difficulty IN ('beginner', 'intermediate', 'advanced')),

created_at      TIMESTAMP NOT NULL DEFAULT now(),
updated_at      TIMESTAMP NOT NULL DEFAULT now()
)

Content tables under a Space:

Question (
id              UUID PRIMARY KEY,
space_id        UUID REFERENCES Space(id),
question_type   TEXT,
body            TEXT,
-- answers stored in Answer table
created_at      TIMESTAMP NOT NULL DEFAULT now(),
updated_at      TIMESTAMP NOT NULL DEFAULT now()
)

Answer (
id              UUID PRIMARY KEY,
question_id     UUID REFERENCES Question(id),
text            TEXT,
is_correct      BOOLEAN,
position        INT
)

FlashCard (
id              UUID PRIMARY KEY,
space_id        UUID REFERENCES Space(id),
front           TEXT,
back            TEXT,
created_at      TIMESTAMP NOT NULL DEFAULT now(),
updated_at      TIMESTAMP NOT NULL DEFAULT now()
)

Problem (
id              UUID PRIMARY KEY,
space_id        UUID REFERENCES Space(id),
question        TEXT,
solution        TEXT,
-- steps stored in ProblemStep table
created_at      TIMESTAMP NOT NULL DEFAULT now(),
updated_at      TIMESTAMP NOT NULL DEFAULT now()
)

ProblemStep (
id              UUID PRIMARY KEY,
problem_id      UUID REFERENCES Problem(id),
body            TEXT,
position        INT
)

---

## 🔗 Important Mapping (Don't Skip)

Connect content → concepts:

SourceConcept (
source_id       UUID REFERENCES Source(id),
concept_id      UUID REFERENCES Concept(id),
PRIMARY KEY (source_id, concept_id)
)

👉 This enables:

* "This PDF teaches these concepts"
* "Find all content for this concept"

---

## 🧠 Mental Model

Collection (owned by User)
↓
Source  ──────────────────────────────┐
↓                                 │
Topic                              │ (provenance)
↓                                 │
Concept ─── ConceptRelation (graph)   │
↓                                 │
Space ◄───────────────────────────┘
↓
Questions / FlashCards / Problems


👉 Concept is the center. Space is the content container linked to both Concept and Source.
