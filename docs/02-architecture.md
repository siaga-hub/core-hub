# 02 — Architecture (from ADR-001, Accepted)

## 1. Style
**Modular monolith** (FastAPI) with strict module boundaries; Postgres **schema per module**; in-process domain events with a transactional **outbox** table (so we can extract services/bus later). Extract Tracking and Dispatch first only if load demands.

Modules: `identity`, `tenant`, `booking`, `pricing`, `dispatch`, `fleet`, `driver`, `tracking`, `finance`, `notification`, plus `core` (shared kernel: config, db, tenancy, errors, ids, money, time, events, audit).

Route groups (same JWT, role/tenant checks per group): `/api/v1/erp/*`, `/api/v1/driver/*`, `/api/v1/traveler/*`, plus `/health`, `/ready`.

## 2. Stack
| Concern | Choice |
|---|---|
| API | FastAPI, Pydantic v2, SQLAlchemy 2.0 async (asyncpg), Alembic, GeoAlchemy2 |
| Jobs | ARQ on Redis (T−24h confirmations, offer timeouts, notifications, settlements) |
| PDF | WeasyPrint (quotes/invoices, later) |
| DB | Supabase Postgres + PostGIS; `numeric` money; append-only ledger; monthly-partitioned GPS history (sampled) |
| Cache/live | Redis: latest driver location, dispatch locks, OTP throttle, permission cache |
| Files | Supabase Storage, signed upload URLs |
| Auth | Supabase Auth; phone OTP (drivers/travelers), email+password+MFA (staff); Send SMS Hook → FastAPI → local SL SMS gateway; Custom Access Token Hook adds `active_tenant_id`, `roles` |
| Authorization | Own DB tables, enforced in FastAPI deps, cached in Redis. Keycloak deferred |
| Web | Next.js App Router, TS, Ant Design, TanStack Query/Table, Zod, Orval client, Google Maps JS |
| Mobile | React Native + Expo (dev builds, Expo Router), TanStack Query (persisted) + Zustand + SQLite, react-native-maps, expo-notifications + FCM, i18next, Transistorsoft background geolocation (HTTP batch sync), Maestro |
| Live tracking | Driver app → HTTPS batch POST every 15–30 s → Redis (latest) + partitioned table; ops/traveler view via WebSocket/SSE. MQTT deferred (~1,000+ concurrent drivers) |
| Integrations | Google Maps behind a `maps` abstraction (cache routes/distances); local SMS gateway; Resend/SES email; WhatsApp Cloud API; payments deferred |
| Quality | pytest + Testcontainers/local Supabase, Playwright, Maestro; Sentry; PostHog; uptime monitor |
| Hosting | Singapore: Railway (API, worker, Redis), Vercel (web; Pro before commercial go-live), Supabase (Pro before go-live), Cloudflare (DNS/TLS/WAF) |
| Envs | local → staging → production |

## 3. Tenancy & isolation
- `tenant_id` on every business table; service-layer filter **and** RLS.
- API connects as role `siaga_app` (NOT superuser, NOT `BYPASSRLS`); tables use `ENABLE` + `FORCE ROW LEVEL SECURITY`.
- Each request transaction runs `SET LOCAL app.tenant_id = '<uuid>'` (via `set_config('app.tenant_id', :t, true)`); policies compare `tenant_id = current_setting('app.tenant_id')::uuid`.
- Platform-level tables (tenants, plans, platform_roles) are tenant-free and only reachable from platform-admin paths using a separate role/policy.
- With a transaction-mode pooler + asyncpg set `statement_cache_size=0`; prefer session pooler/direct for the API.
- Required test: tenant A can never read/write tenant B rows (per table, automated).

## 4. Identity & access model
```
auth.users (Supabase)
 ├─ platform_roles   → platform_admin, support
 ├─ memberships      → user × tenant × role (tenant_admin, ops, finance, driver)
 └─ traveler_profile → marketplace traveler (tenant-free)
roles → role_permissions → permissions (booking.create, fleet.edit, payout.approve …)
tenants → subscriptions → plans → plan_features (module.fleet, max_vehicles, app.tracking …)
```
One person may hold several roles (driver + traveler; driver in 2 tenants). Tenant switch → token refresh with new `active_tenant_id`. Permissions/entitlements are never stored in the IdP.

## 5. Data conventions
UUIDv7 primary keys (app-generated); `created_at`, `updated_at`, `created_by`, `updated_by`; soft-delete only where business needs history (`deleted_at`); optimistic locking `version` int on contended rows (offers, assignments, wallets); enums as Postgres enums or lookup tables (prefer lookup/text+check for easy migration); geography(Point,4326) for locations; audit via `core.audit_log`.

## 6. Explicitly deferred (revisit trigger)
Keycloak (enterprise SSO) · MQTT/EMQX (~1,000 concurrent drivers) · Kafka/RabbitMQ (services extracted) · Citus (DB exceeds vertical + partitioning) · AWS RDS/ECS (bill > ~$200 or SLA) · Grafana/OTel stack (multi-service) · Unleash (rollouts beyond entitlements).

## 7. Cost envelope
Build ≈ $5–10/mo. Go-live ≈ $50–140/mo plus Transistorsoft licence, Apple $99/yr, Google Play $25. Watch Google Maps, SMS OTP, WhatsApp message costs (cache routes, rate-limit OTP).
