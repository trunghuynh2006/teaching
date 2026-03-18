Constraints for concept extraction:

- Each concept must be atomic — it covers exactly one idea.
- canonical_name must be the most widely recognised name for the concept.
- description must be self-contained: a reader who has never seen the source text must understand what the concept is.
- Do not duplicate concepts. If two names refer to the same idea, use the most canonical name and list the others as aliases.
- Only include prerequisites that are themselves concepts in the extracted list or are universally known fundamentals.
- tags must be lowercase and hyphen-separated (e.g. "data-structures", "machine-learning").
- Omit optional fields (domain, tags, aliases, prerequisites) only when they genuinely do not apply.
