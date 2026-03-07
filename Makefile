SHELL := /bin/bash

API_DIR := apps/api2
AI_DIR := apps/ai
WEB_DIR := apps/web
PNPM_BIN ?= /home/trung/.nvm/versions/node/v22.16.0/bin/pnpm

.PHONY: help start-frontend start-backend start-ai seed-users generate-models generate-sqlc generate-sqlc-ai

help:
	@echo "Available targets:"
	@echo "  make start-frontend                 # Start Vite frontend dev server"
	@echo "  make start-backend                  # Start Go backend dev server"
	@echo "  make start-ai                       # Start Go AI service dev server"
	@echo "  make seed-users                     # Seed demo users in PostgreSQL"
	@echo "  make generate-models                # Generate shared models from JSON schema"
	@echo "  make generate-sqlc                  # Generate SQLC typed queries for api2"
	@echo "  make generate-sqlc-ai               # Generate SQLC typed queries for ai"

start-frontend:
	$(PNPM_BIN) --filter web dev

start-backend:
	cd $(API_DIR) && go run .

start-ai:
	cd $(AI_DIR) && go run .

seed-users:
	cd $(API_DIR) && go run . seed-users

generate-models:
	go run ./scripts/generate_shared_models.go

generate-sqlc:
	cd $(API_DIR) && go run github.com/sqlc-dev/sqlc/cmd/sqlc@v1.28.0 generate -f sqlc.yaml

generate-sqlc-ai:
	cd $(AI_DIR) && go run github.com/sqlc-dev/sqlc/cmd/sqlc@v1.28.0 generate -f sqlc.yaml
