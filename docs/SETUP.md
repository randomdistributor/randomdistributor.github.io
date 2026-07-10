# Setup

## Prerequisites (this machine)

| Tool | Needed | Status here | Action |
|---|---|---|---|
| Flutter | buyer/supplier apps | ✅ 3.44 installed | ready |
| Node.js | React admin (Vite) | ⚠️ **v6 installed — too old** | install Node 20 LTS |
| Supabase project | backend | — | create free project |
| Git | version control | ✅ 2.54 | ready |

> **Important:** the React admin panel needs **Node 18+ (20 LTS recommended)**. The Node on
> this machine is v6.10.1, which cannot run modern tooling. Install Node 20 from
> nodejs.org (or via nvm-windows) before scaffolding `admin/`.

## 1. Supabase backend

1. Create a free project at supabase.com. Copy the **Project URL**, **anon key**, and
   **service_role key** (Settings → API).
2. Open the SQL editor and run the migrations **in order**:
   `0001_schema.sql` → `0002_rls.sql` → `0003_functions_views.sql`.
   Optionally `0004_seed.sql` for demo data.
   (Or use the Supabase CLI: `supabase db push` once the CLI is installed and linked.)
3. Storage → create a bucket `product-images`:
   public read, authenticated write. Compress images to ~200–400 KB on upload.
4. Create the first **admin** user (Authentication → Add user), then insert a matching
   `profiles` row with `role = 'admin'` (SQL editor).

## 2. Provisioning suppliers / buyers (no public signup)

For each party the admin:
1. creates an auth user (email + password),
2. inserts a `profiles` row (`role = 'supplier'|'buyer'`),
3. inserts the `suppliers` / `buyers` row with `profile_id` = that user's id,
4. adds phone number(s).

(The admin panel will wrap steps 1–4 in one form.)

## 3. Environment values

Copy `.env.example` where needed and fill:

```
SUPABASE_URL=...
SUPABASE_ANON_KEY=...          # apps + admin (safe to ship, RLS protects data)
SUPABASE_SERVICE_ROLE_KEY=...  # server/admin-only, NEVER ship in an app
```

## 4. Running the apps (after scaffolding, next phase)

- Buyer app:   `cd apps/buyer && flutter pub get && flutter run`
- Supplier app: `cd apps/supplier && flutter pub get && flutter run`
- Admin panel:  `cd admin && npm install && npm run dev`  (needs Node 20)

## Verifying the wall

After seeding, log in as a buyer and confirm:
- `select * from products` → **denied / empty** (buyer has no product RLS access);
- `select * from buyer_catalog` → rows with `selling_price`, **no** `supplier_price`;
- `select * from suppliers` / `select * from margin_rules` → **empty**.

Log in as a supplier and confirm `buyer_catalog`, `orders`, `buyers` all return nothing,
while `supplier_order_items` shows only their own supplier price.
