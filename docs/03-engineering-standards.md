# 03 — Engineering Standards

## 1. Repository layout
```
siaga/
├─ CLAUDE.md
├─ Makefile  README.md  .env.example  .gitignore  .editorconfig
├─ package.json  pnpm-workspace.yaml  turbo.json  .npmrc  .nvmrc
├─ docker-compose.yml           # redis, api, worker (supabase runs via CLI)
├─ .github/workflows/           # ci.yml, deploy-*.yml
├─ docs/                        # 01..04 + adr/ + runbooks/
├─ supabase/                    # config.toml, seed.sql, auth hooks (SQL) ONLY
├─ infra/                       # railway/vercel notes, cloudflare, scripts
├─ apps/
│  ├─ web/                      # Next.js ops/ERP
│  ├─ driver/                   # Expo driver app
│  └─ traveler/                 # placeholder README only (Phase 1b)
├─ packages/
│  ├─ api-client/               # generated from OpenAPI (Orval) – do not hand edit
│  ├─ i18n/                     # si/ta/en JSON + shared keys
│  ├─ ui/                       # shared web components (optional, keep tiny)
│  └─ config/                   # tsconfig, eslint, prettier presets
└─ services/
   └─ api/                      # FastAPI
```

### Backend (`services/api`)
```
services/api/
├─ pyproject.toml  uv.lock  alembic.ini  Dockerfile  .importlinter
├─ migrations/
│  ├─ env.py  script.py.mako  helpers.py     # rls(), audit_trigger(), updated_at_trigger()
│  └─ versions/                               # YYYYMMDD_HHMM_<module>_<slug>.py
├─ src/siaga/
│  ├─ main.py                  # app factory, routers, middleware
│  ├─ worker.py                # ARQ entry
│  ├─ core/
│  │  ├─ config.py  db.py  tenancy.py  security.py  errors.py
│  │  ├─ logging.py  ids.py  money.py  time.py  events.py  outbox.py  audit.py
│  │  └─ pagination.py  deps.py
│  ├─ modules/
│  │  └─ <module>/
│  │     ├─ public.py          # ONLY thing other modules may import
│  │     ├─ models.py          # SQLAlchemy (schema = module name)
│  │     ├─ schemas.py         # Pydantic in/out
│  │     ├─ repository.py      # DB access, always tenant-scoped
│  │     ├─ service.py         # business logic
│  │     ├─ events.py          # domain events published/consumed
│  │     ├─ jobs.py            # ARQ tasks
│  │     └─ api/ {erp.py, driver.py, traveler.py}   # only the audiences that exist
│  └─ integrations/            # maps/, sms/, whatsapp/, email/, storage/ (adapters behind interfaces)
└─ tests/
   ├─ conftest.py  factories.py
   ├─ unit/  integration/  security/ (tenant isolation, RBAC)  
   └─ modules/<module>/
```

### Web (`apps/web`)
```
src/app/(auth)/ (dashboard)/…      # route groups; server components by default
src/features/<module>/             # components, hooks, queries, forms (mirrors backend modules)
src/lib/ (api, auth, i18n, utils)  src/components/  src/styles/
e2e/                               # Playwright
```

### Driver app (`apps/driver`)
```
app/                               # Expo Router routes
src/features/<module>/  src/lib/ (api, auth, db(sqlite), sync, i18n, geo)
src/components/  src/stores/  assets/  .maestro/
```
Expo + pnpm monorepo: use `node-linker=hoisted` in `.npmrc` (or follow current Expo monorepo guidance); keep Metro config monorepo-aware.

## 2. Database & migrations
1. **Alembic only.** `supabase/` holds config, seed and auth-hook SQL, never app tables. Do not edit schema in the Supabase dashboard.
2. One Postgres schema per module (`booking`, `fleet`, …) plus `core` (audit_log, outbox, idempotency) . Alembic `include_schemas=True`; version table `core.alembic_version`. Create extensions (`postgis`, `pgcrypto`, `btree_gist`) in the first migration.
3. File naming: `YYYYMMDD_HHMM_<module>_<slug>.py`; message prefix `module: what`. One concern per migration. Never edit an applied migration; fix forward.
4. Every tenant table migration calls helpers: `enable_rls(table)` (ENABLE + FORCE + tenant policy), `add_updated_at_trigger(table)`, and index `(tenant_id, …)`.
5. Roles: `siaga_migrator` (owner, runs Alembic), `siaga_app` (API: DML only, RLS applies, no BYPASSRLS), `siaga_readonly` (reporting). Grants are in migrations.
6. **Zero-downtime rule (expand → migrate → contract):** add nullable column/new table first; backfill in a separate step/job; enforce NOT NULL and drop old only in a later release. No long locks: `CREATE INDEX CONCURRENTLY` (outside transaction block), batched backfills.
7. Downgrades required unless the migration is explicitly destructive (then `raise` with note + ADR).
8. Append-only ledger: trigger rejects UPDATE/DELETE on `finance.ledger_entries`; deferred constraint trigger enforces balanced debit/credit per `transaction_id`.
9. Partitioning: `tracking.location_points` partitioned monthly by `recorded_at`; a job creates next month's partition ahead of time; old partitions archived, not deleted blindly.
10. CI checks on a clean database: `alembic upgrade head` → `alembic check` (no model drift) → `alembic downgrade -1` → `upgrade head`; plus RLS test suite.
11. Seeds: idempotent `make seed` (Tenant #1, roles/permissions, plans/features, demo vehicles/drivers in dev only). Reference data (permissions list) lives in migrations/seed code, not manual SQL.
12. Backups: Supabase Pro PITR before go-live; document a **tested restore** in `docs/runbooks/restore.md`.

## 3. API conventions
- Versioned `/api/v1`; resource-oriented; snake_case JSON.
- Auth: Bearer JWT (Supabase). Deps: `get_principal()` → `require_permission("booking.create")` → tenant context applied to the DB session.
- Errors: RFC 7807 problem+json with stable `code` (e.g. `booking.vehicle_unavailable`).
- Pagination: cursor-based (`limit`, `cursor`); filters as query params.
- Idempotency: `Idempotency-Key` header on create/accept/payment-like endpoints, stored in `core.idempotency_keys`.
- Request-ID middleware; structured JSON logs with `request_id`, `tenant_id`, `user_id` (no PII).
- Rate limiting (Redis) especially OTP/login; OpenAPI tags per audience; run `make gen-client` after changes.
- Long work → ARQ job, not request thread. Realtime: WebSocket/SSE channel per tenant.

## 4. Frontend conventions
TypeScript strict. Server state via TanStack Query + generated client; forms with react-hook-form + Zod; Ant Design for ERP tables/forms; permission-aware UI via a `usePermission()` hook (UI hiding is cosmetic, server enforces). All strings via i18n keys. Mobile: offline-first writes go to SQLite outbox and sync with retries + idempotency keys; every screen must handle slow/no network.

## 5. Sri Lanka–specific data rules
- Phone: normalise to E.164 `+94XXXXXXXXX`; accept `07X…` input.
- NIC: accept old (9 digits + V/X) and new (12 digits) formats; store raw + normalised; **encrypt-at-rest sensitive IDs** and restrict access (PDPA).
- Vehicle plate: store as typed + normalised uppercase; validate loosely (formats vary by era/province), do not hard-reject.
- Currency LKR, display `Rs. 12,500.00`; dates in `Asia/Colombo`; support Sinhala/Tamil fonts (Noto Sans Sinhala/Tamil) in web and PDFs.
- Vehicle documents modeled generically (type, number, issued/expiry, file) so permit/insurance rule changes don't need migrations.
- Toll/highway costs are **actuals** captured with photo; never baked into fixed price.

## 6. Testing
- API: pytest, real Postgres (local Supabase or Testcontainers), factories; **security suite** proves tenant isolation per table and RBAC per endpoint group.
- Unit-test pricing and dispatch ranking heavily (pure functions).
- Web: Playwright smoke (login, create booking). Mobile: Maestro (login, accept offer) from Sprint 2+.
- Coverage is a signal, not a target; every bug gets a regression test.

## 7. Git, CI, environments
- Trunk-based: short-lived branches `feat/…`, `fix/…`; Conventional Commits; PR checklist (migration reviewed, tests, docs/ADR, `.env.example`).
- CI (GitHub Actions): path-filtered jobs → lint, typecheck, API tests (with Postgres+PostGIS service), migration round-trip, web build, import-linter, gen-client drift check.
- Pre-commit: ruff, ruff-format, prettier, eslint, gitleaks.
- Envs: local (Supabase CLI + docker compose), staging (auto-deploy `main`), production (manual approve / tag). Config via env vars; separate Supabase projects per env.
- Observability: Sentry in api/web/mobile, `/health` + `/ready`, uptime monitor, alert on error spikes and failed jobs.

## 8. Security checklist
Secrets never in git; least-privilege DB roles; signed upload URLs with content-type/size limits; virus/type check on documents later; audit log for sensitive reads of KYC docs; OTP rate limits + SMS cost caps; CORS locked to known origins; Cloudflare WAF in front; dependency updates (Renovate/Dependabot).

## 9. ADR process
`docs/adr/NNNN-title.md` (Context, Decision, Consequences). Required for any stack change, new infrastructure, data-model pivots, or deviation from these standards. Start with `0001-tech-stack.md` (summarising `02-architecture.md`).
