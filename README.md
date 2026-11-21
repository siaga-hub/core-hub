# Siaga

Transport-operations platform for hire and tour fleets in Sri Lanka. Multi-tenant from day one.
Product and architecture docs are in [docs/](docs/). Working rules for Claude Code are in [CLAUDE.md](CLAUDE.md).

## Prerequisites (WSL2 Ubuntu on Windows; keep this repo inside the WSL filesystem)

- Node 24 LTS (see `.nvmrc`) and pnpm (via corepack)
- Python 3.12 managed by uv (`uv python install 3.12`)
- Docker with compose (Docker Desktop with WSL integration enabled)
- Supabase CLI, GNU make, git

## Quickstart

```bash
cp .env.example .env
make setup      # install deps and git hooks
make dev        # supabase + redis + api + worker + web
make migrate    # apply Alembic migrations
make seed       # Tenant #1, roles, dev users
make test lint typecheck
```

Run `make help` for every target. Status of the current sprint: [docs/04-sprint-plan.md](docs/04-sprint-plan.md).
