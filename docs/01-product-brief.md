# 01 — Product Brief (Siaga)

*Version 0.2 · Owner: CEO / Chief Architect · Supersedes Baseline Requirements v0.1 positioning*

## 1. Vision & positioning
A Sri Lanka–first platform replacing WhatsApp driver groups, Facebook posts and word-of-mouth for **long-distance and multi-day vehicle hires**. Run first by our own company, later sold to other hire/tour operators.

Position as **"transport operations platform for hire & tour fleets"**, not a generic travel ERP. Rationale (market research 001): itinerary/DMC costing is crowded (Travify, EasyTour Pro, Indian CRMs, CodeGen at the top); fleet tools are GPS-only (Dialog, KLOUDIP); marketplaces are availability-based with no guarantee (PickMe, Uber Intercity) or plain listings (Voya, TaxiHire). Nobody joins **booking + company/freelance dispatch + trip finance**, and nobody serves the **local long-trip traveler**.

## 2. Problems
| Who | Today | Pain |
|---|---|---|
| Drivers | Trips posted in WhatsApp groups | Everyone reads everything; first-to-reply wins; no fairness/history |
| Local travelers | Facebook, friends | Don't know vehicle/driver until pickup; no guarantee; disputes on tolls, batta, waiting, return leg |
| Ride apps | Short on-demand rides | Availability-based dispatch, drivers avoid long trips, no confirmation guarantee |
| Operators (future tenants) | WhatsApp + Excel | No dispatch board, no driver ledger, no document-expiry control |

## 3. Users
Travelers (local first), **company drivers** and **freelance owner-drivers**, ops/dispatch, finance, tenant admin, platform admin/support.

## 4. Decisions log
| # | Decision |
|---|---|
| D1 | Drivers = company + freelance (two driver/vehicle types) |
| D2 | Revenue = commission (marketplace) + margin (direct bookings). Internally unified: `Traveler Price − Driver Payout = Company Share` |
| D3 | Pricing = hybrid: fixed system price for standard trips; "Request Quote" for complex multi-day tours handled by ops |
| D4 | Dispatch priority: company vehicles first, then freelance |
| D5 | Payments Phase 1 simple: traveler pays driver (cash/bank transfer), app records; freelance company share via wallet/settlement. Gateways = later research |
| D6 | One codebase for marketplace and tenant tracking app, switched by tenant config + entitlements |
| D7 | Multi-tenant from day 1; our company = Tenant #1; no billing/self-signup yet |
| D8 | Centralized authentication; one identity across web/apps/tenants; RBAC |

## 5. Phasing
- **Phase 1a (now):** Ops Web (ERP core) + Driver App
- **Phase 1b:** Traveler App
- **Phase 2:** sell to local operators: tenant onboarding, tenant tracking app, subscription billing, module licensing
- **Phase 3:** global: multi-currency, tax, localization, regional maps, GDPR-grade controls

## 6. Functional requirements — Phase 1a

### Ops Web / ERP core
- Booking console: app bookings + phone/WhatsApp/walk-in entered by staff (same flow, same pricing)
- Dispatch board: auto-dispatch status, manual override, reassignment, SOS alerts
- Fleet: company vehicles, documents with expiry alerts (revenue licence, insurance, permits), maintenance log (basic)
- Drivers: company vs freelance, KYC/verification workflow, reliability score, suspension
- Pricing rules engine: per vehicle class, seasonal, route overrides, min fares; ops override within bounds (audited)
- Basic finance: trip ledger, driver payouts, freelance wallet/settlements, company-share report
- Live map of active trips; audit log on every price/assignment change
- Users, roles, permissions, tenant settings

### Driver App
- Phone OTP login; onboarding with document upload (NIC, licence, revenue licence, insurance, vehicle photos)
- Vehicle profile(s), availability calendar (multi-day blocking), home base, preferred routes
- **Filtered trip feed**: only trips matching vehicle class, seats, radius, free dates, return-leg fit
- Offer shows **driver payout**, route, days, stops; accept/decline with timeout
- Trip execution: start/end, odometer photo, waiting log, toll/parking photo + amount, expense notes
- Background GPS with offline buffering; low-data mode
- Earnings, settlement statement, wallet balance (freelance)
- Sinhala / Tamil / English

### Traveler App (Phase 1b, summary)
Phone OTP, create trip (multi-stop, one-way/return/multi-day), instant fixed price with breakdown or quote request, booking confirmation showing real vehicle photos/plate/driver, live tracking, share trip, SOS, in-app trip changes with re-priced delta, ratings, receipts.

## 7. Pricing & dispatch logic
```
Traveler Price = Rate_per_km[class] × trip_km
               + Return_empty_factor × return_km          (one-way only)
               + Day_rate × days + Batta × days + Night_out × nights
               + Waiting_rate × waiting_hours beyond free
               + Tolls/Parking (actuals, pass-through)
Driver Payout  = payout rule table (class / route / driver type)
Company Share  = Traveler Price − Driver Payout
```
All rates configurable per tenant. Route distances cached (maps abstraction).

**Dispatch waterfall**
1. Free matching **company vehicle** → auto-assign
2. Else offer to **top-N freelance drivers** ranked by distance to pickup, availability fit, rating, reliability, return-leg match
3. Offer window 5–15 min (configurable by lead time); **first valid accept wins** (atomic; `SELECT … FOR UPDATE SKIP LOCKED` / Redis lock)
4. No accept → widen radius / raise payout within bounds / escalate to ops
5. Scheduled trips: confirm driver at T−24h; backup driver for high-value trips
6. No-show → instant reassignment + reliability penalty

## 8. Trust & verification
Driver KYC + licence + revenue licence + **insurance type check** (private vs hiring cover); dated vehicle photos with periodic re-verification; reliability score; traveler OTP + no-show blacklist; booking guarantee policy (replacement driver or credit). SLTDA tourist-driver/guide registration is optional metadata, not a gate.

## 9. Payments Phase 1
Traveler → driver cash/bank transfer, driver confirms receipt in app. Company-vehicle trips collected to company. Freelance company share via prepaid wallet top-up or periodic settlement; block new offers if wallet negative beyond limit. Gateways/LANKAQR/escrow/FX = research track.

## 10. Non-functional
HA for Tenant #1 production (backups + tested restore, zero-downtime deploys); offline-first mobile, battery-friendly GPS, low-data mode; si/ta/en Unicode, LKR first; OIDC/OAuth2, RBAC + tenant isolation, encryption, audit logs; **Sri Lanka PDPA** compliant, GDPR-ready later; central logs/metrics/alerts.

## 11. Risks
Disintermediation (guarantee, ratings, history, driver priority benefits); cold start (WhatsApp group as funnel: teaser + app link, accept only in app); insurance/legal for private vehicles; price disputes (transparent breakdown, in-app change approval, toll photo evidence); driver rejection of fixed payouts (payout bounds, surge, ops escalation); rural connectivity (offline-first, SMS fallback); local driver-association resistance (onboard associations, no forced exclusivity); NTC regulation of app taxis still pending (keep permit/doc model flexible).

## 12. Open questions (do not block Sprint 0)
Commission % and payout tables; insurance requirements; local SMS gateway choice; payments research; team/timeline; consumer brand vs company brand; whether to charge subscription/wallet fee vs pure commission (zero-commission listing sites set expectations).

## 13. Success metrics
Active verified drivers; booking→assignment time; % auto-dispatched; no-show rate; cancellation rate; repeat traveler rate; disputes per 100 trips.
