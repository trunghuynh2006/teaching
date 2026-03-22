SHELL := /bin/bash

API_DIR := apps/api2
AI_DIR := apps/ai
WEB_DIR := apps/web
PNPM_BIN ?= /home/trung/.nvm/versions/node/v22.16.0/bin/pnpm

.PHONY: help start-frontend start-backend start-ai seed-users seed-data generate-models generate-sqlc generate-sqlc-ai drop-db create-db reset-db

help:
	@echo "Available targets:"
	@echo "  make start-frontend                 # Start Vite frontend dev server"
	@echo "  make start-backend                  # Start Go backend dev server"
	@echo "  make start-ai                       # Start Go AI service dev server"
	@echo "  make seed-users                     # Seed demo users in PostgreSQL"
	@echo "  make seed-data                      # Seed demo content (folders, sources, concepts, topics, …)"
	@echo "  make generate-models                # Generate shared models from JSON schema"
	@echo "  make generate-sqlc                  # Generate SQLC typed queries for api2"
	@echo "  make generate-sqlc-ai               # Generate SQLC typed queries for ai"
	@echo "  make drop-db                        # Drop the dev database (irreversible!)"
	@echo "  make create-db                      # Create the dev database and apply schema"
	@echo "  make reset-db                       # Drop, recreate, and seed the dev database"

start-frontend:
	$(PNPM_BIN) --filter web dev

start-backend:
	cd $(API_DIR) && go run .

start-ai:
	cd $(AI_DIR) && go run .

seed-users:
	cd $(API_DIR) && go run . seed-users

seed-data:
	psql -h localhost -U postgres -d study_platform -f scripts/seed_data.sql

generate-models:
	go run ./scripts/generate_shared_models.go

generate-sqlc:
	cd $(API_DIR) && go run github.com/sqlc-dev/sqlc/cmd/sqlc@v1.28.0 generate -f sqlc.yaml

generate-sqlc-ai:
	cd $(AI_DIR) && go run github.com/sqlc-dev/sqlc/cmd/sqlc@v1.28.0 generate -f sqlc.yaml

drop-db:
	@echo "WARNING: This will drop the 'study_platform' database!"
	@read -p "Are you sure? [y/N] " confirm && [ "$$confirm" = "y" ]
	psql -h localhost -U postgres -c "SELECT pg_terminate_backend(pid) FROM pg_stat_activity WHERE datname = 'study_platform' AND pid <> pg_backend_pid();"
	dropdb --if-exists -h localhost -U postgres study_platform

create-db:
	createdb -h localhost -U postgres study_platform
	psql -h localhost -U postgres -d study_platform -f $(API_DIR)/db/schema.sql

reset-db: drop-db create-db seed-users seed-data
