# 04 — Sprint Plan (Phase 1a: Ops Web + Driver App)

Current sprint: **Sprint 0 — Foundation**

## Sprint 0 — Foundation (no business features)
Goal: a developer can clone, run `make setup && make dev`, log in as staff on web and as a driver (test OTP) on the app, and every request is tenant-isolated, tested and deployable to staging.

### Phase gates (each ends with a commit and verification)
**P0 Repo & tooling.** Monorepo, pnpm/turbo, Makefile, editorconfig, pre-commit, README, `.env.example`, ADR 0001. *Gate:* `make lint` passes on empty skeleton.

**P1 Local infra.** `supabase init` + `config.toml` (phone auth with `[auth.sms.test_otp]` for dev, hook config), `docker-compose.yml` (redis, api, worker). *Gate:* `make dev` brings up DB, Redis, API health.

**P2 Backend skeleton + DB.** FastAPI app factory, config, async DB, logging, errors (problem+json), request-id, health/ready, ARQ worker. Alembic setup with helpers; migrations for: extensions, roles, `core` (audit_log, outbox, idempotency_keys), `tenant` (tenants, plans, plan_features, subscriptions), `identity` (platform_roles, memberships, roles, permissions, role_permissions, traveler_profile). RLS on tenant tables. Seed: Tenant #1, roles/permissions. *Gate:* migration round-trip passes; **tenant isolation tests pass**.

**P3 Auth & RBAC.** JWT verification (Supabase JWKS), principal + tenant context middleware, `require_permission`, Custom Access Token Hook (SQL) adding `active_tenant_id` + `roles`, tenant switch endpoint, Send SMS Hook endpoint with dev stub (log only) and `integrations/sms` interface. `GET /api/v1/erp/me`, `GET /api/v1/driver/me`. *Gate:* tests for staff, driver, wrong-tenant, missing-permission.

**P4 Web skeleton.** Next.js + Ant Design layout, i18n (en first, si/ta wired), Supabase auth (email+password), protected routes, tenant switcher, `make gen-client` pipeline, a "Users & roles" read-only page proving end-to-end. *Gate:* Playwright login smoke.

**P5 Driver app skeleton.** Expo dev build, Expo Router, i18next (si/ta/en), phone OTP login (test OTP), secure token storage, API client, offline-ready SQLite + TanStack Query persistence scaffolding, home screen showing `/driver/me`. *Gate:* runs on Android device/emulator against local API.

**P6 CI/CD & staging.** GitHub Actions (all checks incl. migration round-trip, import-linter, client drift), staging deploy for API/worker (Railway), web (Vercel), Supabase staging project, Sentry wired, uptime check. *Gate:* merged PR auto-deploys to staging; health green.

**P7 Hardening & docs.** README quickstart verified on a clean checkout, runbooks (`restore.md`, `deploy.md`), update this file with Sprint 1 detailed tasks. *Gate:* fresh-clone setup works.

### Sprint 0 Definition of Done
All gates green; CLAUDE.md commands accurate; no TODOs without an issue note; secrets scanned.

## Sprint 1 — Fleet & Drivers
Vehicles (classes, seats, AC, photos), vehicle documents with expiry alerts, driver profiles (company vs freelance), KYC upload + verification workflow in Ops Web, driver app onboarding + vehicle profile + availability calendar. Storage with signed URLs. Notifications skeleton (push + SMS adapter).

## Sprint 2 — Booking & Pricing
Maps abstraction (+ route cache), pricing rules engine (class/season/route overrides, bounds), booking model + staff booking console (phone/walk-in), price breakdown, quote request flow, audit log on price changes, unit tests for pricing.

## Sprint 3 — Dispatch
Company-first assignment, freelance offer waterfall (ranking, windows, atomic accept, widen/escalate), driver trip feed + offers in app, ops dispatch board, T−24h confirmation job, no-show handling + reliability score.

## Sprint 4 — Trip execution & tracking
Start/end trip, odometer photos, waiting log, toll/parking capture, Transistorsoft background GPS with batch sync, live map (WebSocket/SSE), SOS alerts.

## Sprint 5 — Finance
Double-entry ledger, trip settlement, driver earnings, freelance wallet + company share, settlement statements, company-share reports, wallet-negative offer blocking.

## Sprint 6 — Pilot hardening
Real drivers pilot with our WhatsApp funnel, performance/battery tuning, Sinhala/Tamil QA, backups + restore drill, Supabase Pro + Vercel Pro go-live checklist. Then Phase 1b (Traveler App).
