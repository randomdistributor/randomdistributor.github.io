-- Random Distributors — Row Level Security (the privacy wall)
-- Apply after 0001. This is the load-bearing security control.
--
-- Key idea: RLS is ROW-level, but our wall is partly COLUMN-level
-- (buyers must not see supplier_price; suppliers must not see selling price/margin).
-- So base tables holding both-sides data are locked to admin only, and each side
-- reads through the security-definer VIEWS created in 0003, which project only the
-- columns that side is allowed to see. Owner-scoped tables (a supplier's own products,
-- a buyer's own orders) get direct policies where no cross-party column exists.

-- ---------------------------------------------------------------------------
-- Auth helper functions (security definer so they can read profiles under RLS)
-- ---------------------------------------------------------------------------
create or replace function current_app_role() returns user_role
language sql stable security definer set search_path = public as $$
  select role from profiles where id = auth.uid()
$$;

create or replace function is_admin() returns boolean
language sql stable security definer set search_path = public as $$
  select coalesce((select role = 'admin' from profiles where id = auth.uid()), false)
$$;

create or replace function is_supplier() returns boolean
language sql stable security definer set search_path = public as $$
  select coalesce((select role = 'supplier' from profiles where id = auth.uid()), false)
$$;

create or replace function is_buyer() returns boolean
language sql stable security definer set search_path = public as $$
  select coalesce((select role = 'buyer' from profiles where id = auth.uid()), false)
$$;

create or replace function current_supplier_id() returns uuid
language sql stable security definer set search_path = public as $$
  select id from suppliers where profile_id = auth.uid()
$$;

create or replace function current_buyer_id() returns uuid
language sql stable security definer set search_path = public as $$
  select id from buyers where profile_id = auth.uid()
$$;

-- ---------------------------------------------------------------------------
-- Enable RLS everywhere
-- ---------------------------------------------------------------------------
alter table profiles         enable row level security;
alter table organization     enable row level security;
alter table suppliers        enable row level security;
alter table buyers           enable row level security;
alter table supplier_phones  enable row level security;
alter table buyer_phones     enable row level security;
alter table categories       enable row level security;
alter table brands           enable row level security;
alter table products         enable row level security;
alter table product_images   enable row level security;
alter table margin_rules     enable row level security;
alter table orders           enable row level security;
alter table supplier_orders  enable row level security;
alter table order_items      enable row level security;
alter table dispatches       enable row level security;
alter table dispatch_items   enable row level security;
alter table receipts         enable row level security;
alter table receipt_items    enable row level security;
alter table payments         enable row level security;
alter table ledger_entries   enable row level security;
alter table settlements      enable row level security;
alter table notifications    enable row level security;
alter table audit_log        enable row level security;

-- ---------------------------------------------------------------------------
-- Identity
-- ---------------------------------------------------------------------------
create policy p_profiles_self   on profiles for select using (id = auth.uid() or is_admin());
create policy p_profiles_admin  on profiles for all    using (is_admin()) with check (is_admin());

-- organization: readable by any authenticated user (name/UPI/QR shown at checkout); admin writes.
create policy p_org_read  on organization for select using (auth.uid() is not null);
create policy p_org_admin on organization for all    using (is_admin()) with check (is_admin());

-- suppliers: admin all; a supplier sees only its own row; buyers never.
create policy p_suppliers_admin on suppliers for all    using (is_admin()) with check (is_admin());
create policy p_suppliers_self  on suppliers for select using (id = current_supplier_id());

-- buyers: admin all; a buyer sees only its own row; suppliers never.
create policy p_buyers_admin on buyers for all    using (is_admin()) with check (is_admin());
create policy p_buyers_self  on buyers for select using (id = current_buyer_id());

create policy p_sphones_admin on supplier_phones for all using (is_admin()) with check (is_admin());
create policy p_sphones_self  on supplier_phones for all
  using (supplier_id = current_supplier_id()) with check (supplier_id = current_supplier_id());

create policy p_bphones_admin on buyer_phones for all using (is_admin()) with check (is_admin());
create policy p_bphones_self  on buyer_phones for all
  using (buyer_id = current_buyer_id()) with check (buyer_id = current_buyer_id());

-- ---------------------------------------------------------------------------
-- Catalog reference data — both sides may read; admin writes
-- ---------------------------------------------------------------------------
create policy p_categories_read  on categories for select using (auth.uid() is not null);
create policy p_categories_admin on categories for all    using (is_admin()) with check (is_admin());
create policy p_brands_read      on brands     for select using (auth.uid() is not null);
create policy p_brands_admin     on brands     for all    using (is_admin()) with check (is_admin());

-- products: admin all; supplier manages OWN products. Buyers get NO direct access
-- (would expose supplier_price/supplier_id) — they read buyer_catalog view in 0003.
create policy p_products_admin on products for all using (is_admin()) with check (is_admin());
create policy p_products_self  on products for all
  using (supplier_id = current_supplier_id())
  with check (supplier_id = current_supplier_id());

-- product_images: admin all; supplier manages own; buyers may READ (urls only, no
-- supplier identity) so the catalog can render images.
create policy p_pimages_admin on product_images for all using (is_admin()) with check (is_admin());
create policy p_pimages_self  on product_images for all
  using (exists (select 1 from products p where p.id = product_id and p.supplier_id = current_supplier_id()))
  with check (exists (select 1 from products p where p.id = product_id and p.supplier_id = current_supplier_id()));
create policy p_pimages_read  on product_images for select using (is_buyer());

-- margin_rules: admin only — secret from BOTH sides.
create policy p_margins_admin on margin_rules for all using (is_admin()) with check (is_admin());

-- ---------------------------------------------------------------------------
-- Orders & fulfilment
-- ---------------------------------------------------------------------------
-- orders (buyer-side, no supplier columns): admin all; buyer sees/creates own,
-- may edit only while still 'created'. Suppliers never.
create policy p_orders_admin  on orders for all using (is_admin()) with check (is_admin());
create policy p_orders_select on orders for select using (buyer_id = current_buyer_id());
create policy p_orders_insert on orders for insert with check (buyer_id = current_buyer_id());
create policy p_orders_update on orders for update
  using (buyer_id = current_buyer_id() and status = 'created')
  with check (buyer_id = current_buyer_id());

-- supplier_orders (no buyer columns): admin all; supplier reads/updates own.
create policy p_sorders_admin  on supplier_orders for all using (is_admin()) with check (is_admin());
create policy p_sorders_select on supplier_orders for select using (supplier_id = current_supplier_id());
create policy p_sorders_update on supplier_orders for update
  using (supplier_id = current_supplier_id()) with check (supplier_id = current_supplier_id());

-- order_items holds BOTH sides' prices -> admin only at table level.
-- Buyers read buyer_order_items view; suppliers read supplier_order_items view (0003).
-- Buyer writes go through place_order() RPC (0003), which runs as definer.
create policy p_oitems_admin on order_items for all using (is_admin()) with check (is_admin());

-- dispatches: admin all; supplier manages own (via its supplier_order).
-- Buyers read a buyer-safe dispatch view (0003) that hides the commercial dispatch bill.
create policy p_dispatches_admin on dispatches for all using (is_admin()) with check (is_admin());
create policy p_dispatches_self on dispatches for all
  using (exists (select 1 from supplier_orders so where so.id = supplier_order_id and so.supplier_id = current_supplier_id()))
  with check (exists (select 1 from supplier_orders so where so.id = supplier_order_id and so.supplier_id = current_supplier_id()));

-- dispatch_items has supplier unit_price -> admin + owning supplier only; buyers via view.
create policy p_ditems_admin on dispatch_items for all using (is_admin()) with check (is_admin());
create policy p_ditems_self on dispatch_items for all
  using (exists (select 1 from dispatches d join supplier_orders so on so.id = d.supplier_order_id
                 where d.id = dispatch_id and so.supplier_id = current_supplier_id()))
  with check (exists (select 1 from dispatches d join supplier_orders so on so.id = d.supplier_order_id
                 where d.id = dispatch_id and so.supplier_id = current_supplier_id()));

-- receipts / receipt_items: admin all; buyer manages own; suppliers never (contains buyer_id).
create policy p_receipts_admin on receipts for all using (is_admin()) with check (is_admin());
create policy p_receipts_self on receipts for all
  using (buyer_id = current_buyer_id()) with check (buyer_id = current_buyer_id());
create policy p_ritems_admin on receipt_items for all using (is_admin()) with check (is_admin());
create policy p_ritems_self on receipt_items for all
  using (exists (select 1 from receipts r where r.id = receipt_id and r.buyer_id = current_buyer_id()))
  with check (exists (select 1 from receipts r where r.id = receipt_id and r.buyer_id = current_buyer_id()));

-- ---------------------------------------------------------------------------
-- Money
-- ---------------------------------------------------------------------------
-- payments: admin writes; each party reads only its own payments.
create policy p_payments_admin on payments for all using (is_admin()) with check (is_admin());
create policy p_payments_self on payments for select using (
  (party_type = 'buyer'    and party_id = current_buyer_id()) or
  (party_type = 'supplier' and party_id = current_supplier_id())
);

-- ledger_entries: admin writes; each party reads only its own ledger.
create policy p_ledger_admin on ledger_entries for all using (is_admin()) with check (is_admin());
create policy p_ledger_self on ledger_entries for select using (
  (party_type = 'buyer'    and party_id = current_buyer_id()) or
  (party_type = 'supplier' and party_id = current_supplier_id())
);

-- settlements: admin all; supplier reads own. Buyers never (row carries supplier_id).
create policy p_settlements_admin on settlements for all using (is_admin()) with check (is_admin());
create policy p_settlements_self on settlements for select using (supplier_id = current_supplier_id());

-- ---------------------------------------------------------------------------
-- Communication & audit
-- ---------------------------------------------------------------------------
create policy p_notif_admin on notifications for all using (is_admin()) with check (is_admin());
create policy p_notif_self on notifications for select using (
  (recipient_type = 'buyer'    and recipient_id = current_buyer_id()) or
  (recipient_type = 'supplier' and recipient_id = current_supplier_id())
);

create policy p_audit_admin on audit_log for all using (is_admin()) with check (is_admin());
