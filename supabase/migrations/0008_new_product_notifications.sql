-- Random Distributors — Phase 1 notifications: queue a notification for every
-- active buyer when a product is added, and let buyers read/mark them in-app.
-- Push (FCM) and WhatsApp become extra senders draining the same queue later.
-- Apply after 0007.

-- Buyers can opt out of new-product broadcasts (required for WhatsApp later,
-- and good manners for push).
alter table buyers add column if not exists notify_new_products boolean not null default true;

-- Track when a recipient has seen a notification (drives the unread badge).
alter table notifications add column if not exists read_at timestamptz;

create index if not exists notifications_recipient_idx
  on notifications (recipient_type, recipient_id, created_at desc);

-- ---------------------------------------------------------------------------
-- Trigger: product added -> one notification row per opted-in active buyer.
-- SECURITY DEFINER because the *supplier* inserting the product has no write
-- access to notifications (admin-only under RLS).
-- The payload keeps only the product reference; the app reads live price and
-- image from buyer_catalog, so images uploaded after the insert still show.
-- ---------------------------------------------------------------------------
create or replace function notify_buyers_new_product() returns trigger
language plpgsql security definer set search_path = public as $$
begin
  if new.status <> 'active' then
    return new;
  end if;

  insert into notifications (recipient_type, recipient_id, channel, template, status, payload)
  select 'buyer', b.id, 'inapp', 'new_product', 'sent',
         jsonb_build_object(
           'product_id',   new.id,
           'product_code', new.product_code,
           'description',  new.description
         )
  from buyers b
  where b.status = 'active' and b.notify_new_products;

  return new;
end $$;

drop trigger if exists t_notify_new_product on products;
create trigger t_notify_new_product after insert on products
  for each row execute function notify_buyers_new_product();

-- ---------------------------------------------------------------------------
-- Let a party mark its own notifications read (select policy already exists).
-- ---------------------------------------------------------------------------
drop policy if exists p_notif_self_update on notifications;
create policy p_notif_self_update on notifications for update to authenticated
  using (
    (recipient_type = 'buyer'    and recipient_id = current_buyer_id()) or
    (recipient_type = 'supplier' and recipient_id = current_supplier_id())
  )
  with check (
    (recipient_type = 'buyer'    and recipient_id = current_buyer_id()) or
    (recipient_type = 'supplier' and recipient_id = current_supplier_id())
  );
