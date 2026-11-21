# Siaga

Sri Lankan **transport-operations platform for hire & tour fleets** (cars, vans, buses): bookings, dispatch to company + freelance drivers, live trip tracking, driver payouts and trip finance. Multi-tenant from day 1. Our own travel company is **Tenant #1**; later sold as a modular ERP to other hire/tour operators.

Core promise: **right trip → only to the right driver; the traveler sees the real vehicle + driver before the trip, with a guaranteed booking.** Focus: long-distance and multi-day trips (outstation, pilgrimage, wedding, family, airport runs), mostly local travelers first.

I (the owner) am the **only developer**, building with Claude Code. Prefer boring, simple, maintainable. Cost matters.

## Docs (read the relevant one before working in that area)
- `docs/01-product-brief.md` – requirements, decisions D1–D8, pricing/dispatch rules
- `docs/02-architecture.md` – stack, modules, auth/tenancy model, hosting
- `docs/03-engineering-standards.md` – folder structure, migrations, API/DB conventions, testing, git
- `docs/04-sprint-plan.md` – sprint scopes + acceptance criteria (current sprint marked)
- `docs/adr/` – decision records. Any deviation from the stack = write a new ADR first, do not silently change.

## Scope guard (do NOT build unless I ask)
Hotel contracts, DMC tour costing, full itinerary builder, payment gateways, MQTT/EMQX, Keycloak, Kafka, Kubernetes, subscription billing, self-signup for tenants, foreign-traveler features. Phase 1a = **Ops Web + Driver App**. Traveler App is Phase 1b.

## Stack (fixed, see ADR-001)
- Backend: **FastAPI + Pydantic v2**, SQLAlchemy 2.0 async, **Alembic** (single source of truth for schema), GeoAlchemy2, ARQ + Redis. Python 3.12, **uv**, ruff, pyright, pytest.
- DB/Auth/Storage: **Supabase Postgres + PostGIS**, Supabase Auth (phone OTP for drivers/travelers, email+MFA for staff), Supabase Storage.
- Web: **Next.js App Router + TypeScript**, Ant Design, TanStack Query/Table, Zod, generated API client (Orval).
- Mobile: **React Native + Expo** (dev builds, Expo Router), TanStack Query + Zustand + SQLite offline, i18next (si/ta/en), Transistorsoft background geolocation (later sprint).
- Monorepo: **pnpm + Turborepo**. CI: GitHub Actions. Errors: Sentry. Hosting: Railway (API/worker/Redis), Vercel (web), Supabase, Cloudflare; region **Singapore**.

## Repo map
```
apps/web  apps/driver  apps/traveler(placeholder)
services/api            # FastAPI modular monolith
packages/api-client packages/i18n packages/ui packages/config
supabase/               # config.toml, seed, auth hook SQL ONLY (no app schema)
docs/  infra/  .github/
```

## Commands (all via Makefile; keep it updated)
- `make setup` install deps · `make dev` start supabase + redis + api + worker + web
- `make migrate` alembic upgrade head · `make migration m="module: message"` autogenerate
- `make test` / `make test-api` / `make test-web` · `make lint` · `make typecheck`
- `make gen-client` regenerate OpenAPI TS client · `make seed` Tenant #1 + demo data

## Hard rules
1. **Tenancy**: every business table has `tenant_id uuid not null`; every query filtered by tenant in the service layer AND protected by RLS. API DB role is a non-superuser, no BYPASSRLS, `FORCE ROW LEVEL SECURITY`; set `SET LOCAL app.tenant_id` per transaction. Never trust `tenant_id` from request bodies; derive from token.
2. **Schema changes only through Alembic.** Never edit applied migrations. Never use the Supabase dashboard to change app schema. RLS policies live in migrations.
3. **Money**: `numeric(14,2)` + `currency` (LKR default); Python `Decimal`; never float. Ledger tables are **append-only double-entry** (DB trigger blocks UPDATE/DELETE).
4. **Module boundaries**: a module may import another module only via its `public.py`. Never touch another module's tables or internals. Enforced by import-linter in CI.
5. **Authorization** lives in our DB (roles/permissions/entitlements), enforced with FastAPI `Depends()`. Token carries only `sub`, `active_tenant_id`, `roles`.
6. **Time**: store `timestamptz` UTC; display `Asia/Colombo`. **Phones**: E.164 (+94…). Never log PII/OTP/tokens.
7. **API contract is OpenAPI-first**; after any backend schema change run `make gen-client`. Errors use RFC 7807 problem+json. List endpoints paginated (cursor).
8. Every price/assignment/payout change writes an **audit log** row.
9. All user-facing strings go through i18n (si/ta/en). No hardcoded text in apps.
10. Secrets only in env vars; keep `.env.example` current. Never commit `.env`.

## Workflow
- Start non-trivial work in **plan mode**; list files you will touch. Small, reviewable commits; Conventional Commits (`feat(booking): …`).
- Definition of done: lint + typecheck + tests pass, migration upgrades/downgrades cleanly, docs/ADR updated if behavior or decision changed, `.env.example` updated.
- Write tests with the code (pytest for services + RLS isolation tests; Playwright for web smoke; Maestro for mobile flows later).
- If a requirement is ambiguous and the answer changes architecture or data model, ask me; otherwise choose the simplest option, state the assumption in the PR/commit, and continue.
- Keep this file short. Put long explanations in `docs/`.
