# Shared Models — Schema Reference

Concept is the center of the system. Everything connects to it.

---

## Core entities

### Folder
Top-level container. Groups Knowledge entries, Topics, and Spaces together for a teacher's workspace.

| Field | Type | Notes |
|---|---|---|
| id | string | PK |
| name | string | required |
| description | string? | |
| domain | string? | e.g. `mathematics`, `computer-science` |
| theme | string? | UI color theme |
| icon | string? | |
| created_by / updated_by | string? | |
| created_time / updated_time | datetime? | |

---

### Knowledge (Source)
A piece of content — text, PDF, audio, video, or article — that is the raw material of the system. Books extend Knowledge 1-to-1.

| Field | Type | Notes |
|---|---|---|
| id | string | PK |
| folder_id | string | FK → Folder |
| type | enum | `text`, `pdf`, `audio`, `video`, `article` |
| status | enum | `draft`, `processing`, `processed`, `failed` |
| title | string? | |
| content | string | main text content |
| file_url | string? | for non-text sources |
| created_by / updated_by | string? | |
| created_time / updated_time | datetime? | |

**Extensions:**
- `Book` — extends a Knowledge entry with `author`, `isbn`, `published_at`
- `Chapter` — belongs to a Book with `title`, `content`, `position`

---

### Topic
A subject area that groups related concepts. Belongs to a Folder. The relationship to concepts is owned here (`concept_ids`), and the relationship to Sources is via the `SourceTopic` join.

| Field | Type | Notes |
|---|---|---|
| id | string | PK |
| folder_id | string | FK → Folder |
| name | string | required |
| concept_ids | string[] | ordered list of Concept ids |
| description | string? | |
| created_by / updated_by | string? | |
| created_time / updated_time | datetime? | |

---

### Concept ★ (center)
A neutral, reusable unit of knowledge. Not owned by any Topic or Source — it is referenced by them. Scoped by `domain` to prevent ambiguous deduplication across fields.

| Field | Type | Notes |
|---|---|---|
| id | string | PK |
| canonical_name | string | required |
| domain | string? | e.g. `physics`, `linguistics` |
| description | string? | |
| tags | string[] | search/filter tags |
| created_by / updated_by | string? | |
| created_time / updated_time | datetime? | |

**Graph relations:**
- `ConceptAlias` — alternative names for a concept (`concept_id`, `alias`)
- `ConceptRelation` — directed edge between two concepts

### ConceptRelation
| Field | Type | Notes |
|---|---|---|
| concept_a_id | string | source concept |
| concept_b_id | string | target concept |
| relation_type | enum | `prerequisite`, `part_of`, `related_to` |
| created_by | string? | |
| created_time | datetime? | |

---

### Lesson (LearningUnit)
A teaching artifact linked to a Concept and optionally to a Source. Type and difficulty are enumerated.

| Field | Type | Notes |
|---|---|---|
| id | string | PK |
| concept_id | string? | FK → Concept |
| source_id | string? | FK → Knowledge |
| type | enum | `lesson`, `quiz`, `flashcard`, `video` |
| difficulty | enum? | `beginner`, `intermediate`, `advanced` |
| title | string | required |
| description | string? | |
| duration_minutes | integer? | |
| is_published | boolean | default false |
| tags | string[] | |
| created_by / updated_by | string? | |
| created_time / updated_time | datetime? | |

---

## Join tables

### SourceConcept
Links a Knowledge entry to the Concepts it covers. Enables "find all sources for this concept" and "find all concepts in this source".

| Field | Type |
|---|---|
| source_id | FK → Knowledge |
| concept_id | FK → Concept |

### SourceTopic
Links a Knowledge entry to the Topics it covers. Enables bidirectional source ↔ topic queries.

| Field | Type |
|---|---|
| source_id | FK → Knowledge |
| topic_id | FK → Topic |

---

## Space system (app layer)

Spaces are the interactive workspace layer — they live inside Folders and hold practice items. They are not part of the knowledge graph.

| Space type | Items | Detail view |
|---|---|---|
| Problem | Problems (question + steps + solution) | ProblemDetail |
| Exercise | Exercises | SpaceItemsSidebar |
| Question | Questions | QuestionDetail |
| Anki | Flashcards | AnkiDetail |
| Note / Quiz / Topic / Other | — | SpaceManager |

---

## Mental model

```
Folder
├── Knowledge (Source) ──┬── SourceTopic ──► Topic ──► concept_ids ──► Concept
│   ├── Book             └── SourceConcept ──────────────────────────► Concept
│   └── Chapter                                                            │
│                                                                  ConceptRelation
└── Space                                                          ConceptAlias
    └── Items (Problem / Question / Anki card)
                                                          Concept
                                                             └── Lesson (LearningUnit)
```

Concept is referenced from Topics, Sources, and LearningUnits — it owns nothing itself.
