# 🧱 Final Simple Schema (v1)

---

## 1️⃣ Collection

Collection (
id              UUID PRIMARY KEY,
name            TEXT NOT NULL,
description     TEXT,
created_at      TIMESTAMP,
updated_at      TIMESTAMP
)

👉 Example: “Electronics”, “Robotics”

---

## 2️⃣ Source (raw content)

Source (
id              UUID PRIMARY KEY,
collection_id   UUID REFERENCES Collection(id),

type            TEXT,          -- pdf, audio, video, article
title           TEXT,
file_url        TEXT,

created_at      TIMESTAMP,
updated_at      TIMESTAMP
)

👉 One source = one uploaded item (PDF, audio, etc.)

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

created_at      TIMESTAMP,
updated_at      TIMESTAMP
)

Aliases (for deduplication):

ConceptAlias (
id              UUID PRIMARY KEY,
concept_id      UUID REFERENCES Concept(id),
alias           TEXT NOT NULL
)

Relations (graph):

ConceptRelation (
concept_a_id    UUID REFERENCES Concept(id),
concept_b_id    UUID REFERENCES Concept(id),

relation_type   TEXT,          -- prerequisite, part_of, related_to

PRIMARY KEY (concept_a_id, concept_b_id, relation_type)
)

---

## 5️⃣ LearningUnit (teaching layer)

LearningUnit (
id              UUID PRIMARY KEY,
concept_id      UUID REFERENCES Concept(id),

type            TEXT,          -- lesson, quiz, flashcard, video
title           TEXT,
content         TEXT,          -- markdown / json

difficulty      TEXT,          -- beginner, intermediate, advanced

created_at      TIMESTAMP,
updated_at      TIMESTAMP
)

---

## 🔗 Important Mapping (Don’t Skip)

Connect content → concepts:

SourceConcept (
source_id       UUID REFERENCES Source(id),
concept_id      UUID REFERENCES Concept(id),
PRIMARY KEY (source_id, concept_id)
)

👉 This enables:

* “This PDF teaches these concepts”
* “Find all content for this concept”

---

## 🧠 Mental Model

Collection
↓
Source  ───────────────┐
↓                  │
Topic                 │
↓
Concept ─── ConceptRelation (graph)
↓
LearningUnit


👉 Concept is the center
