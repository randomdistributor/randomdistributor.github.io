-- Random Distributors — demo/seed data (OPTIONAL, for local testing only).
-- Safe to skip in production. Leaves profile_id NULL on parties because real
-- suppliers/buyers are linked to Supabase auth users when the admin provisions them.
--
-- NOTE: RLS-gated views (buyer_catalog, etc.) return rows only for an authenticated
-- buyer/admin session. Running this in the SQL editor (service role) lets you eyeball
-- the base tables and compute_selling_price(), not the buyer views.

insert into organization (system_name, admin_name, admin_phone, upi_id)
select 'Random Distributors', 'Admin Desk', '+910000000000', 'admin@upi'
where not exists (select 1 from organization);

with s as (
  insert into suppliers (name, business_name) values
    ('Supplier A', 'A Traders'),
    ('Supplier B', 'B Enterprises')
  returning id, name
),
cat as (
  insert into categories (name) values ('Kitchenware'), ('Toys') returning id, name
),
br as (
  insert into brands (name) values ('BrandX'), ('BrandY') returning id, name
)
insert into products
  (supplier_id, product_code, description, category_id, brand_id, unit,
   available_qty, supplier_price, units_per_carton, sale_mode, moq)
select
  (select id from s where name = 'Supplier A'),
  'A-1001', 'Steel lunch box', (select id from cat where name = 'Kitchenware'),
  (select id from br where name = 'BrandX'), 'pcs', 240, 200.00, 12, 'carton_only'::sale_mode, 24
union all select
  (select id from s where name = 'Supplier A'),
  'A-1002', 'Ceramic mug', (select id from cat where name = 'Kitchenware'),
  (select id from br where name = 'BrandX'), 'pcs', 500, 90.00, 6, 'loose_allowed'::sale_mode, 6
union all select
  (select id from s where name = 'Supplier B'),
  'B-2001', 'Toy car', (select id from cat where name = 'Toys'),
  (select id from br where name = 'BrandY'), 'pcs', 120, 390.00, 4, 'carton_only'::sale_mode, 8;

-- margins: supplier-level 25% for A, category-level flat 50 for Toys,
-- product override on A-1001 to 30%
insert into margin_rules (scope, scope_ref_id, margin_type, margin_value)
select 'supplier', id, 'percent', 25 from suppliers where name = 'Supplier A';
insert into margin_rules (scope, scope_ref_id, margin_type, margin_value)
select 'category', id, 'flat', 50 from categories where name = 'Toys';
insert into margin_rules (scope, scope_ref_id, margin_type, margin_value)
select 'product_override', id, 'percent', 30 from products where product_code = 'A-1001';

-- quick check (run as service role): expected A-1001 -> 260 (30% override),
-- A-1002 -> 112.50 (25% supplier), B-2001 -> 440 (flat 50 category)
-- select product_code, supplier_price, compute_selling_price(id) from products order by product_code;
