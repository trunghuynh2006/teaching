SHELL := /bin/bash

API_DIR := apps/api2
AI_DIR := apps/ai
WEB_DIR := apps/web
WIKI_DIR := apps/wikiprovider
PNPM_BIN ?= /home/trung/.nvm/versions/node/v22.16.0/bin/pnpm

PGHOST ?= localhost
PGUSER ?= postgres
PGPASSWORD ?= postgres
export PGPASSWORD

.PHONY: help start-frontend start-backend start-ai start-wiki seed-users seed-data generate-models generate-sqlc generate-sqlc-ai drop-db create-db reset-db drop-db-ai create-db-ai reset-db-ai

help:
	@echo "Available targets:"
	@echo "  make start-frontend                 # Start Vite frontend dev server"
	@echo "  make start-backend                  # Start Go backend dev server"
	@echo "  make start-ai                       # Start Go AI service dev server"
	@echo "  make start-wiki                     # Start Go wikiprovider service dev server"
	@echo "  make seed-users                     # Seed demo users in PostgreSQL"
	@echo "  make seed-data                      # Seed demo content (folders, sources, concepts, topics, …)"
	@echo "  make generate-models                # Generate shared models from JSON schema"
	@echo "  make generate-sqlc                  # Generate SQLC typed queries for api2"
	@echo "  make generate-sqlc-ai               # Generate SQLC typed queries for ai"
	@echo "  make drop-db                        # Drop the api2 database (irreversible!)"
	@echo "  make create-db                      # Create the api2 database and apply schema"
	@echo "  make reset-db                       # Drop, recreate, and seed the api2 database"
	@echo "  make drop-db-ai                     # Drop the ai database (irreversible!)"
	@echo "  make create-db-ai                   # Create the ai database and apply schema"
	@echo "  make reset-db-ai                    # Drop and recreate the ai database"

start-frontend:
	$(PNPM_BIN) --filter web dev

start-backend:
	cd $(API_DIR) && go run .

start-ai:
	cd $(AI_DIR) && go run .

start-wiki:
	cd $(WIKI_DIR) && go run .

seed-users:
	cd $(API_DIR) && go run . seed-users

seed-data:
	psql -h $(PGHOST) -U $(PGUSER) -d study_platform_api -f scripts/seed_data.sql

generate-models:
	go run ./scripts/generate_shared_models.go

generate-sqlc:
	cd $(API_DIR) && go run github.com/sqlc-dev/sqlc/cmd/sqlc@v1.28.0 generate -f sqlc.yaml

generate-sqlc-ai:
	cd $(AI_DIR) && go run github.com/sqlc-dev/sqlc/cmd/sqlc@v1.28.0 generate -f sqlc.yaml

drop-db:
	@echo "WARNING: This will drop the 'study_platform_api' database!"
	@read -p "Are you sure? [y/N] " confirm && [ "$$confirm" = "y" ]
	psql -h $(PGHOST) -U $(PGUSER) -c "SELECT pg_terminate_backend(pid) FROM pg_stat_activity WHERE datname = 'study_platform_api' AND pid <> pg_backend_pid();"
	dropdb --if-exists -h $(PGHOST) -U $(PGUSER) study_platform_api

create-db:
	createdb -h $(PGHOST) -U $(PGUSER) study_platform_api
	psql -h $(PGHOST) -U $(PGUSER) -d study_platform_api -f $(API_DIR)/db/schema.sql

reset-db: drop-db create-db seed-users seed-data

drop-db-ai:
	@echo "WARNING: This will drop the 'study_platform_ai' database!"
	@read -p "Are you sure? [y/N] " confirm && [ "$$confirm" = "y" ]
	psql -h $(PGHOST) -U $(PGUSER) -c "SELECT pg_terminate_backend(pid) FROM pg_stat_activity WHERE datname = 'study_platform_ai' AND pid <> pg_backend_pid();"
	dropdb --if-exists -h $(PGHOST) -U $(PGUSER) study_platform_ai

create-db-ai:
	createdb -h $(PGHOST) -U $(PGUSER) study_platform_ai
	psql -h $(PGHOST) -U $(PGUSER) -d study_platform_ai -f $(AI_DIR)/db/schema.sql

reset-db-ai: drop-db-ai create-db-ai
