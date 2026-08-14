-- Random Distributors — let suppliers create categories/brands while adding a product.
-- Previously both tables were admin-write only, so a supplier had no way to add a
-- brand/category that didn't already exist. Reference data is not sensitive (it reveals
-- nothing about the other party), so suppliers may INSERT. Editing/deleting stays admin-only.
-- Apply after 0006.

drop policy if exists p_categories_insert_supplier on categories;
create policy p_categories_insert_supplier on categories
  for insert to authenticated
  with check (is_supplier() or is_admin());

drop policy if exists p_brands_insert_supplier on brands;
create policy p_brands_insert_supplier on brands
  for insert to authenticated
  with check (is_supplier() or is_admin());

-- Keep names unique so the same brand/category isn't created twice.
-- (brands.name already has a UNIQUE constraint from 0001.)
create unique index if not exists categories_name_key on categories (lower(name));
