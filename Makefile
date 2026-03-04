SHELL := /bin/bash

API_DIR := apps/api
WEB_DIR := apps/web
VENV_BIN := $(API_DIR)/.venv/bin
ALEMBIC := $(VENV_BIN)/alembic
UVICORN := $(VENV_BIN)/uvicorn

.PHONY: help start-frontend start-backend migration-up migration-new

help:
	@echo "Available targets:"
	@echo "  make start-frontend                 # Start Vite frontend dev server"
	@echo "  make start-backend                  # Start FastAPI backend dev server"
	@echo "  make migration-up                   # Run Alembic migrations to head"
	@echo "  make migration-new m='message'      # Create new Alembic migration"

start-frontend:
	pnpm --filter web dev

start-backend:
	cd $(API_DIR) && \
	if [ -x "$(abspath $(UVICORN))" ]; then \
		$(abspath $(UVICORN)) app.main:app --reload --host 0.0.0.0 --port 8000; \
	else \
		uvicorn app.main:app --reload --host 0.0.0.0 --port 8000; \
	fi

migration-up:
	cd $(API_DIR) && \
	if [ -x "$(abspath $(ALEMBIC))" ]; then \
		$(abspath $(ALEMBIC)) upgrade head; \
	else \
		alembic upgrade head; \
	fi

migration-new:
	@if [ -z "$(m)" ]; then \
		echo "Usage: make migration-new m='describe change'"; \
		exit 1; \
	fi
	cd $(API_DIR) && \
	if [ -x "$(abspath $(ALEMBIC))" ]; then \
		$(abspath $(ALEMBIC)) revision --autogenerate -m "$(m)"; \
	else \
		alembic revision --autogenerate -m "$(m)"; \
	fi
