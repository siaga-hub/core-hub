# ADR 0001 — Tech stack

Status: Accepted · Date: 2026-11-22

## Context

Siaga is a multi-tenant transport-operations platform for hire and tour fleets, built and run by a single developer with cost as a constraint. Full rationale and the cost envelope are in `docs/02-architecture.md`.

## Decision

- **Backend:** modular monolith. FastAPI, Pydantic v2, SQLAlchemy 2.0 async, Alembic (sole schema authority), ARQ + Redis. Python 3.12 with uv.
- **Data:** Supabase Postgres + PostGIS, schema per module plus `core`. Tenant isolation through `tenant_id`, service-layer filtering and RLS (`ENABLE` + `FORCE`), with a non-superuser `siaga_app` role.
- **Auth:** Supabase Auth (phone OTP, email+password). A Custom Access Token Hook adds `active_tenant_id` and `roles`. Permissions and entitlements live in our DB.
- **Web:** Next.js App Router, TypeScript, Ant Design, TanStack Query, Zod, Orval-generated client.
- **Mobile:** React Native + Expo (dev builds, Expo Router), SQLite offline storage, i18next (si/ta/en).
- **Monorepo and CI:** pnpm + Turborepo, GitHub Actions.
- **Hosting:** Railway (API, worker, Redis), Vercel (web), Supabase, Cloudflare. Region: Singapore.

## Sprint 0 clarifications (do not change the stack)

- The auth hook function is created by an Alembic migration, not loaded from `supabase/`, because it depends on app tables and must be versioned and round-trip tested. `supabase/config.toml` only wires it up.
- `identity.user_settings.active_tenant_id` is the source for the `active_tenant_id` claim.
- No hard foreign key to `auth.users`, so migrations run on a plain Postgres in CI.
- Enums use text + CHECK or lookup tables. Pagination is cursor-based. Both follow the project docs.

## Consequences

Boring, proven pieces and one deployable backend. The deferred items (Keycloak, MQTT, Kafka, Kubernetes) are listed in `docs/02-architecture.md` §6 with revisit triggers. Any stack change needs a new ADR first.
