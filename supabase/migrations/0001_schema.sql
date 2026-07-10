-- Random Distributors — schema
-- Postgres / Supabase. Apply first. RLS is added in 0002, logic in 0003.
--
-- Conventions:
--   * every table has id uuid + created_at/updated_at
--   * money stored as numeric(14,2); quantities as integer (base units)
--   * app identities (suppliers/buyers) hang off Supabase auth via profiles.id

create extension if not exists "pgcrypto";

-- ---------------------------------------------------------------------------
-- Enums
-- ---------------------------------------------------------------------------
create type user_role            as enum ('admin', 'supplier', 'buyer');
create type account_status       as enum ('active', 'disabled');
create type sale_mode            as enum ('loose_allowed', 'carton_only');
create type margin_scope         as enum ('supplier', 'category', 'product', 'product_override');
create type margin_type          as enum ('percent', 'flat');
create type order_status         as enum ('created', 'sent_to_supplier', 'partially_dispatched',
                                          'fully_dispatched', 'partially_received', 'completed', 'cancelled');
create type supplier_order_status as enum ('new', 'viewed', 'partially_dispatched', 'fully_dispatched', 'closed');
create type dispatch_status      as enum ('draft', 'dispatched', 'partially_received', 'received');
create type party_type           as enum ('buyer', 'supplier');
create type payment_direction    as enum ('in', 'out');
create type payment_mode         as enum ('cash', 'upi_qr', 'bank', 'online', 'adjustment');
create type ledger_type          as enum ('order_charge', 'payment_in', 'payment_out',
                                          'settlement', 'credit', 'adjustment');
create type notification_channel as enum ('push', 'whatsapp', 'inapp');
create type notification_status  as enum ('queued', 'sent', 'failed');

-- ---------------------------------------------------------------------------
-- updated_at trigger helper
-- ---------------------------------------------------------------------------
create or replace function set_updated_at() returns trigger
language plpgsql as $$
begin
  new.updated_at = now();
  return new;
end $$;

-- ---------------------------------------------------------------------------
-- Identity
-- ---------------------------------------------------------------------------

-- One row per authenticated user, keyed to Supabase auth.users.
create table profiles (
  id         uuid primary key references auth.users(id) on delete cascade,
  role       user_role      not null,
  status     account_status not null default 'active',
  email      text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table organization (           -- the "System / Admin" identity (single row)
  id             uuid primary key default gen_random_uuid(),
  system_name    text not null,
  admin_name     text,
  admin_phone    text,
  upi_id         text,
  qr_image_url   text,
  created_at     timestamptz not null default now(),
  updated_at     timestamptz not null default now()
);

create table suppliers (
  id            uuid primary key default gen_random_uuid(),
  profile_id    uuid unique references profiles(id) on delete set null,
  name          text not null,
  business_name text,
  gst_no        text,
  address       text,
  status        account_status not null default 'active',
  created_at    timestamptz not null default now(),
  updated_at    timestamptz not null default now()
);

create table buyers (
  id            uuid primary key default gen_random_uuid(),
  profile_id    uuid unique references profiles(id) on delete set null,
  name          text not null,
  business_name text,
  address       text,
  status        account_status not null default 'active',
  created_at    timestamptz not null default now(),
  updated_at    timestamptz not null default now()
);

create table supplier_phones (
  id               uuid primary key default gen_random_uuid(),
  supplier_id      uuid not null references suppliers(id) on delete cascade,
  phone            text not null,
  is_primary       boolean not null default false,
  whatsapp_enabled boolean not null default false,
  created_at       timestamptz not null default now()
);

create table buyer_phones (
  id               uuid primary key default gen_random_uuid(),
  buyer_id         uuid not null references buyers(id) on delete cascade,
  phone            text not null,
  is_primary       boolean not null default false,
  whatsapp_enabled boolean not null default false,
  created_at       timestamptz not null default now()
);

-- ---------------------------------------------------------------------------
-- Catalog
-- ---------------------------------------------------------------------------
create table categories (
  id         uuid primary key default gen_random_uuid(),
  name       text not null,
  parent_id  uuid references categories(id) on delete set null,
  created_at timestamptz not null default now()
);

create table brands (
  id         uuid primary key default gen_random_uuid(),
  name       text not null unique,
  created_at timestamptz not null default now()
);

create table products (
  id               uuid primary key default gen_random_uuid(),
  supplier_id      uuid not null references suppliers(id) on delete cascade,   -- bound to ONE supplier
  product_code     text not null,
  description      text,
  category_id      uuid references categories(id) on delete set null,
  brand_id         uuid references brands(id) on delete set null,
  unit             text not null default 'pcs',
  available_qty    integer not null default 0 check (available_qty >= 0),
  supplier_price   numeric(14,2) not null check (supplier_price >= 0),         -- NEVER shown to buyers
  units_per_carton integer not null default 1 check (units_per_carton >= 1),
  sale_mode        sale_mode not null default 'loose_allowed',
  moq              integer not null default 1 check (moq >= 1),
  status           account_status not null default 'active',
  created_at       timestamptz not null default now(),
  updated_at       timestamptz not null default now(),
  unique (supplier_id, product_code)
);

create table product_images (
  id         uuid primary key default gen_random_uuid(),
  product_id uuid not null references products(id) on delete cascade,
  url        text not null,
  is_primary boolean not null default false,
  sort_order integer not null default 0,
  created_at timestamptz not null default now()
);

-- ---------------------------------------------------------------------------
-- Pricing — margin rules (resolution order handled in 0003)
-- ---------------------------------------------------------------------------
create table margin_rules (
  id           uuid primary key default gen_random_uuid(),
  scope        margin_scope not null,
  scope_ref_id uuid,                       -- supplier/category/product id per scope; null not used
  margin_type  margin_type not null,
  margin_value numeric(14,2) not null check (margin_value >= 0),
  active       boolean not null default true,
  created_at   timestamptz not null default now(),
  updated_at   timestamptz not null default now(),
  unique (scope, scope_ref_id)
);

-- ---------------------------------------------------------------------------
-- Orders & fulfilment
-- ---------------------------------------------------------------------------
create table orders (
  id            uuid primary key default gen_random_uuid(),
  order_no      bigint generated by default as identity,
  buyer_id      uuid not null references buyers(id) on delete restrict,
  status        order_status not null default 'created',
  subtotal      numeric(14,2) not null default 0,   -- buyer-side items subtotal (selling)
  extra_charges numeric(14,2) not null default 0,   -- admin-added, added to buyer bill
  total_amount  numeric(14,2) not null default 0,   -- subtotal + extra_charges
  note          text,
  created_at    timestamptz not null default now(),
  updated_at    timestamptz not null default now()
);

-- One per supplier per order — this is the supplier-facing "System order" (the wall).
create table supplier_orders (
  id                  uuid primary key default gen_random_uuid(),
  supplier_order_no   bigint generated by default as identity,
  order_id            uuid not null references orders(id) on delete cascade,
  supplier_id         uuid not null references suppliers(id) on delete restrict,
  status              supplier_order_status not null default 'new',
  total_supplier_value numeric(14,2) not null default 0,   -- ordered @ supplier price
  created_at          timestamptz not null default now(),
  updated_at          timestamptz not null default now(),
  unique (order_id, supplier_id)
);

create table order_items (
  id                  uuid primary key default gen_random_uuid(),
  order_id            uuid not null references orders(id) on delete cascade,
  supplier_order_id   uuid not null references supplier_orders(id) on delete cascade,
  product_id          uuid not null references products(id) on delete restrict,
  supplier_id         uuid not null references suppliers(id) on delete restrict,
  qty_ordered         integer not null check (qty_ordered > 0),
  buyer_unit_price    numeric(14,2) not null,   -- selling price snapshot (buyer side)
  supplier_unit_price numeric(14,2) not null,   -- supplier price snapshot (supplier side)
  -- packaging snapshot so later product edits don't rewrite history
  units_per_carton_snapshot integer not null default 1,
  sale_mode_snapshot  sale_mode not null default 'loose_allowed',
  line_total_buyer    numeric(14,2) not null,
  line_total_supplier numeric(14,2) not null,
  created_at          timestamptz not null default now(),
  -- enforce MOQ / carton rules at write time
  check (qty_ordered >= 1),
  check (sale_mode_snapshot = 'loose_allowed'
         or (qty_ordered % units_per_carton_snapshot) = 0)
);

create table dispatches (
  id                    uuid primary key default gen_random_uuid(),
  dispatch_no           bigint generated by default as identity,
  supplier_order_id     uuid not null references supplier_orders(id) on delete cascade,
  status                dispatch_status not null default 'draft',
  dispatch_date         date,
  dispatch_copy_image_url text,
  dispatch_bill_image_url text,
  notes                 text,
  created_at            timestamptz not null default now(),
  updated_at            timestamptz not null default now()
);

create table dispatch_items (
  id             uuid primary key default gen_random_uuid(),
  dispatch_id    uuid not null references dispatches(id) on delete cascade,
  order_item_id  uuid not null references order_items(id) on delete restrict,
  qty_dispatched integer not null check (qty_dispatched > 0),   -- short supply => < qty_ordered
  unit_price     numeric(14,2) not null,                         -- supplier price
  created_at     timestamptz not null default now()
);

create table receipts (
  id           uuid primary key default gen_random_uuid(),
  dispatch_id  uuid not null references dispatches(id) on delete cascade,
  buyer_id     uuid not null references buyers(id) on delete restrict,
  confirmed_at timestamptz,
  notes        text,
  created_at   timestamptz not null default now()
);

create table receipt_items (
  id            uuid primary key default gen_random_uuid(),
  receipt_id    uuid not null references receipts(id) on delete cascade,
  order_item_id uuid not null references order_items(id) on delete restrict,
  qty_received  integer not null check (qty_received >= 0),
  created_at    timestamptz not null default now()
);

-- ---------------------------------------------------------------------------
-- Money — payments, ledger, settlement
-- ---------------------------------------------------------------------------
create table payments (
  id              uuid primary key default gen_random_uuid(),
  party_type      party_type not null,
  party_id        uuid not null,                 -- buyer_id or supplier_id per party_type
  order_id        uuid references orders(id) on delete set null,
  amount          numeric(14,2) not null check (amount > 0),
  direction       payment_direction not null,
  mode            payment_mode not null,
  reference_no    text,
  proof_image_url text,
  entered_by      uuid references profiles(id) on delete set null,   -- admin
  paid_on         date not null default current_date,
  note            text,
  created_at      timestamptz not null default now()
);

create table ledger_entries (
  id            uuid primary key default gen_random_uuid(),
  party_type    party_type not null,
  party_id      uuid not null,
  order_id      uuid references orders(id) on delete set null,
  type          ledger_type not null,
  amount        numeric(14,2) not null,          -- signed: + increases what party is owed
  balance_after numeric(14,2),
  ref_payment_id uuid references payments(id) on delete set null,
  note          text,
  created_at    timestamptz not null default now()
);

create table settlements (
  id                  uuid primary key default gen_random_uuid(),
  order_id            uuid not null references orders(id) on delete restrict,
  supplier_id         uuid references suppliers(id) on delete set null,
  supplier_payable    numeric(14,2) not null default 0,   -- dispatched value
  buyer_final_amount  numeric(14,2) not null default 0,   -- received value + extra charges share
  admin_margin_earned numeric(14,2) not null default 0,
  settled_at          timestamptz,
  created_at          timestamptz not null default now()
);

-- ---------------------------------------------------------------------------
-- Communication & audit
-- ---------------------------------------------------------------------------
create table notifications (
  id             uuid primary key default gen_random_uuid(),
  recipient_type party_type,
  recipient_id   uuid,
  channel        notification_channel not null default 'inapp',
  template       text,
  order_id       uuid references orders(id) on delete set null,
  status         notification_status not null default 'queued',
  payload        jsonb,
  sent_at        timestamptz,
  created_at     timestamptz not null default now()
);

create table audit_log (
  id            uuid primary key default gen_random_uuid(),
  actor_user_id uuid references profiles(id) on delete set null,
  action        text not null,
  entity        text,
  entity_id     uuid,
  before        jsonb,
  after         jsonb,
  created_at    timestamptz not null default now()
);

-- ---------------------------------------------------------------------------
-- Indexes for the common access paths
-- ---------------------------------------------------------------------------
create index on products (supplier_id);
create index on products (category_id);
create index on products (brand_id);
create index on product_images (product_id);
create index on orders (buyer_id);
create index on supplier_orders (supplier_id);
create index on supplier_orders (order_id);
create index on order_items (order_id);
create index on order_items (supplier_order_id);
create index on dispatches (supplier_order_id);
create index on dispatch_items (dispatch_id);
create index on receipts (dispatch_id);
create index on ledger_entries (party_type, party_id);
create index on payments (party_type, party_id);

-- ---------------------------------------------------------------------------
-- updated_at triggers
-- ---------------------------------------------------------------------------
create trigger t_profiles_updated       before update on profiles        for each row execute function set_updated_at();
create trigger t_organization_updated   before update on organization    for each row execute function set_updated_at();
create trigger t_suppliers_updated      before update on suppliers       for each row execute function set_updated_at();
create trigger t_buyers_updated         before update on buyers          for each row execute function set_updated_at();
create trigger t_products_updated       before update on products        for each row execute function set_updated_at();
create trigger t_margin_rules_updated   before update on margin_rules    for each row execute function set_updated_at();
create trigger t_orders_updated         before update on orders          for each row execute function set_updated_at();
create trigger t_supplier_orders_updated before update on supplier_orders for each row execute function set_updated_at();
create trigger t_dispatches_updated     before update on dispatches      for each row execute function set_updated_at();
