SHELL := /bin/bash
API := services/api

.DEFAULT_GOAL := help
.PHONY: help setup dev stop migrate migration seed test test-api test-web lint typecheck gen-client

help: ## List targets
	@grep -E '^[a-zA-Z_-]+:.*?## ' $(MAKEFILE_LIST) | awk 'BEGIN {FS = ":.*?## "}; {printf "  %-14s %s\n", $$1, $$2}'

setup: ## Install JS + Python deps, git hooks, .env
	@test -f .env || cp .env.example .env
	pnpm install
	cd $(API) && uv sync
	uv tool install pre-commit >/dev/null 2>&1 || true
	pre-commit install

dev: ## Start supabase + redis + api + worker + web
	supabase start -x studio,imgproxy,edge-runtime,logflare,vector
	docker compose up -d redis api worker
	pnpm --filter web dev

stop: ## Stop everything
	docker compose down
	supabase stop

migrate: ## alembic upgrade head
	cd $(API) && uv run alembic upgrade head

migration: ## make migration m="module: message"
	@test -n "$(m)" || (echo 'usage: make migration m="module: message"' && exit 1)
	cd $(API) && uv run alembic revision --autogenerate -m "$(m)"

seed: ## Idempotent: Tenant #1, roles/permissions, dev users
	cd $(API) && uv run python -m scripts.seed

test: test-api test-web ## All tests

test-api:
	cd $(API) && uv run pytest

test-web:
	pnpm turbo run test

lint:
	pre-commit run --all-files
	pnpm turbo run lint
	cd $(API) && uv run ruff check . && uv run ruff format --check . && uv run lint-imports

typecheck:
	cd $(API) && uv run pyright
	pnpm turbo run typecheck

gen-client: ## Regenerate OpenAPI TS client (packages/api-client)
	cd $(API) && uv run python -m scripts.export_openapi > ../../packages/api-client/openapi.json
	pnpm --filter @siaga/api-client generate
