-- Random Distributors — Storage buckets for product images and dispatch documents.
-- Apply after 0005. Buckets can also be created in the dashboard (Storage), but this
-- keeps it reproducible.

-- product-images: public read (buyers load them via URL); suppliers/admin upload.
insert into storage.buckets (id, name, public)
values ('product-images', 'product-images', true)
on conflict (id) do nothing;

-- dispatch-docs: dispatch copy/bill images. Public for MVP simplicity; URLs are random
-- and the buyer view only ever exposes the delivery copy (not the commercial bill).
-- TODO: harden to a private bucket + signed URLs to fully enforce the wall on bills.
insert into storage.buckets (id, name, public)
values ('dispatch-docs', 'dispatch-docs', true)
on conflict (id) do nothing;

-- ---- policies on storage.objects ----
drop policy if exists "rd product-images read" on storage.objects;
create policy "rd product-images read" on storage.objects
  for select using (bucket_id = 'product-images');

drop policy if exists "rd product-images write" on storage.objects;
create policy "rd product-images write" on storage.objects
  for insert to authenticated
  with check (bucket_id = 'product-images' and (public.is_supplier() or public.is_admin()));

drop policy if exists "rd product-images modify" on storage.objects;
create policy "rd product-images modify" on storage.objects
  for update to authenticated
  using (bucket_id = 'product-images' and (public.is_supplier() or public.is_admin()));

drop policy if exists "rd product-images delete" on storage.objects;
create policy "rd product-images delete" on storage.objects
  for delete to authenticated
  using (bucket_id = 'product-images' and (public.is_supplier() or public.is_admin()));

drop policy if exists "rd dispatch-docs read" on storage.objects;
create policy "rd dispatch-docs read" on storage.objects
  for select using (bucket_id = 'dispatch-docs');

drop policy if exists "rd dispatch-docs write" on storage.objects;
create policy "rd dispatch-docs write" on storage.objects
  for insert to authenticated
  with check (bucket_id = 'dispatch-docs' and (public.is_supplier() or public.is_admin()));
