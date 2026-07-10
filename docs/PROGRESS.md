# Progress log

Tracks what's built and what's next, so work can resume cleanly.

## Phase 0 — Planning ✔
- Requirements captured in [`SPEC.md`](SPEC.md).
- Data model + screens reviewed and approved (mockups signed off).
- Stack chosen: Flutter apps + React admin + Supabase, all free tier.

## Phase 1 — Backend foundation (in progress)
- [x] Project scaffold, README, .gitignore
- [x] Spec + data model docs
- [x] `0001_schema.sql` — tables, enums, constraints (incl. MOQ/carton, ledger)
- [x] `0002_rls.sql` — the privacy wall (Row Level Security)
- [x] `0003_functions_views.sql` — margin resolution, buyer catalog view, wallet, settlement
- [x] `0004_seed.sql` — demo data for local testing
- [x] Git repo initialized (branch `main`; files staged, not yet committed)
- [ ] **Verify migrations apply cleanly against a real Supabase project** (no local
      Postgres/psql on this machine, so the SQL is reviewed but not yet executed)

## Phase 2 — App scaffolding
Decision: **all-Flutter** (buyer app, supplier app, admin web) — no React/Node. Admin is a
Flutter Web build opened in a desktop browser.

- [x] `admin/` Flutter Web panel scaffolded, builds & runs (`flutter build web` clean).
      Screens: login (admin-only, role-checked), dashboard (live counts), suppliers,
      buyers, products (with MOQ/carton), margins (rules + live preview), payments
      (auto-posts to ledger), orders (list), settings (System identity).
      Config in `admin/lib/config.dart` (Supabase URL + anon key baked in; override via
      --dart-define). Run: `cd admin && flutter run -d chrome`.
- [x] Account provisioning: `admin-provision` Edge Function (create login by mobile + PIN,
      reset PIN) written; admin Suppliers/Buyers **Add** now collects mobile + PIN and
      calls it, with a per-row **Reset PIN** action. **Needs deploying** via the Supabase
      dashboard (see `supabase/functions/README.md`).
      Login model: mobile + PIN, mapped internally to `<mobile>@randomdistributors.app`
      (no SMS provider needed). WhatsApp OTP is a later addition.
- [ ] Order detail + settlement UI in admin (currently orders are list-only)
- [ ] Product image upload (Supabase Storage bucket `product-images`)
- [ ] `apps/buyer/` Flutter: catalog, product detail (MOQ/carton), cart, checkout, orders,
      receipt confirm, wallet
- [ ] `apps/supplier/` Flutter: products, add product (image), incoming orders, dispatch,
      account
- [ ] FCM push wiring
- [ ] WhatsApp Business Cloud API integration (Edge Function)

## Open items to confirm with the user
- Supabase project created? URL + keys needed for Phase 2.
- Storage: start on Supabase Storage (1 GB) with on-upload compression; move to
  Cloudflare R2 only if image bandwidth/size demands it.
- iOS timing (Apple Developer account ~$99/yr) — Android first regardless.

## Notes / decisions
- RLS is the load-bearing security control. Any new table that holds supplier- or
  buyer-identifying data MUST get an explicit policy before it ships.
