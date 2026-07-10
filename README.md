# Random Distributors

A private, invite-only **B2B middleman marketplace**. The System (Admin) sits between
**suppliers** and **buyers** so that neither side ever sees the other. Suppliers list
products (image-led) at their price; buyers browse and buy at a selling price derived
from supplier price + an admin-configured margin. Money flows through the Admin, who
settles both sides after goods are dispatched and received.

> **Status:** foundation in progress. See [`docs/PROGRESS.md`](docs/PROGRESS.md).

## The core idea

- **Two audiences, one product catalog, two prices.** Suppliers see their price; buyers
  see the selling price. Neither sees the other's number.
- **A hard privacy wall.** A supplier believes every order comes from the *System*; a
  buyer believes every shipment comes from the *System*. Enforced in the database with
  Row Level Security, not just the UI.
- **Image is the product's identity.** Buyers purchase largely by image; each image binds
  a product to exactly one supplier.
- **Split fulfilment.** One buyer order can contain items from several suppliers and
  silently splits into one `supplier_order` per supplier.
- **Two "final" quantities.** The supplier is settled on what was *dispatched*; the buyer
  is settled on what was *confirmed received*. The Admin absorbs the gap.
- **Admin-run ledger, no payment gateway.** Payments (cash / UPI-QR / bank / online) are
  entered by the Admin. Buyer overpayment becomes wallet credit.

## Architecture

| Layer | Tech | Notes |
|---|---|---|
| Buyer & Supplier apps | Flutter | Android first, iOS later, one codebase |
| Admin panel | React (web) | Cloudflare Pages / Vercel free hosting |
| Backend / DB / Auth / Storage | Supabase (Postgres) | Free tier; RLS enforces the wall |
| Business logic | Postgres functions + Supabase Edge Functions | margin resolution, settlement |
| Product images | Supabase Storage (→ Cloudflare R2 if needed) | compressed on upload |
| Push notifications | Firebase Cloud Messaging | |
| WhatsApp | WhatsApp Business Cloud API | Admin number is the only sender identity |

All chosen to fit **free tiers** at the expected volume (~1,000 products, <20 suppliers,
~100 buyers, <100 orders/month).

## Repository layout

```
random-distributors/
├── docs/                  Spec, data model, progress log
├── supabase/
│   └── migrations/        SQL: schema, RLS (the wall), functions & views
├── apps/
│   ├── buyer/             Flutter buyer app        (scaffolded next phase)
│   └── supplier/          Flutter supplier app     (scaffolded next phase)
└── admin/                 React admin panel        (scaffolded next phase)
```

## Getting started (when ready to wire up)

1. Create a free Supabase project; note the project URL and anon/service keys.
2. Apply migrations in `supabase/migrations/` in order (Supabase SQL editor or CLI).
3. Create a Storage bucket `product-images` (public read, authenticated write).
4. Fill `docs/SETUP.md` env values and scaffold the apps (next phase).

See [`docs/SPEC.md`](docs/SPEC.md) for the full requirements and
[`docs/DATA_MODEL.md`](docs/DATA_MODEL.md) for the schema explained.
