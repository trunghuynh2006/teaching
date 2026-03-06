SHELL := /bin/bash

API_DIR := apps/api2
WEB_DIR := apps/web
PNPM_BIN ?= /home/trung/.nvm/versions/node/v22.16.0/bin/pnpm

.PHONY: help start-frontend start-backend seed-users generate-models

help:
	@echo "Available targets:"
	@echo "  make start-frontend                 # Start Vite frontend dev server"
	@echo "  make start-backend                  # Start Go backend dev server"
	@echo "  make seed-users                     # Seed demo users in PostgreSQL"
	@echo "  make generate-models                # Generate shared models from JSON schema"

start-frontend:
	$(PNPM_BIN) --filter web dev

start-backend:
	cd $(API_DIR) && go run .

seed-users:
	cd $(API_DIR) && go run . seed-users

generate-models:
	go run ./scripts/generate_shared_models.go
