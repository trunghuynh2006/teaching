# single domain
make seed-concept-domain CONCEPT_DOMAIN="microsoft power platform"
make seed-concept-domain CONCEPT_DOMAIN=physics

# multiple domains at once
make seed-concepts
make seed-concepts CONCEPT_DOMAINS="physics mathematics"

# or directly
cd apps/api2 && go run . seed-concepts physics mathematics "computer science"
