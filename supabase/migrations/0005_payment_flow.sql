-- Random Distributors — payment flow: buyer submits payment at checkout (pending),
-- admin confirms it (linked to the order), only then does it hit the ledger.
-- Apply after 0004.

-- ---------------------------------------------------------------------------
-- Payment status
-- ---------------------------------------------------------------------------
do $$ begin
  if not exists (select 1 from pg_type where typname = 'payment_status') then
    create type payment_status as enum ('pending', 'confirmed', 'rejected');
  end if;
end $$;

alter table payments add column if not exists status payment_status not null default 'confirmed';

-- ---------------------------------------------------------------------------
-- Ledger posts ONLY on confirmation (insert-confirmed or update->confirmed).
-- Standalone admin payments default to 'confirmed', so they still post at once.
-- ---------------------------------------------------------------------------
create or replace function payment_to_ledger() returns trigger
language plpgsql security definer set search_path = public as $$
begin
  if new.status = 'confirmed'
     and (tg_op = 'INSERT' or coalesce(old.status::text, '') <> 'confirmed') then
    insert into ledger_entries(party_type, party_id, order_id, type, amount, ref_payment_id, note)
    values (
      new.party_type, new.party_id, new.order_id,
      (case when new.direction = 'in' then 'payment_in' else 'payment_out' end)::ledger_type,
      case when new.direction = 'in' then new.amount else -new.amount end,
      new.id, new.note
    );
  end if;
  return new;
end $$;

drop trigger if exists t_payment_to_ledger on payments;
create trigger t_payment_to_ledger after insert or update on payments
  for each row execute function payment_to_ledger();

-- ---------------------------------------------------------------------------
-- Checkout now captures the buyer's payment as a PENDING payment on the order.
-- (Replaces the old 2-arg signature.)
-- ---------------------------------------------------------------------------
drop function if exists place_order(jsonb, text);

create or replace function place_order(
  p_items          jsonb,
  p_payment_mode   text default null,
  p_payment_amount numeric default 0,
  p_note           text default null
) returns uuid
language plpgsql security definer set search_path = public as $$
declare
  v_buyer uuid := current_buyer_id();
  v_order uuid;
  v_item  jsonb;
  v_pid   uuid;
  v_qty   integer;
  v_prod  products%rowtype;
  v_sell  numeric(14,2);
  v_so    uuid;
  v_subtotal numeric(14,2) := 0;
begin
  if v_buyer is null then raise exception 'caller is not a buyer'; end if;
  if p_items is null or jsonb_array_length(p_items) = 0 then raise exception 'empty order'; end if;

  insert into orders(buyer_id, status, note) values (v_buyer, 'created', p_note) returning id into v_order;

  for v_item in select * from jsonb_array_elements(p_items) loop
    v_pid := (v_item->>'product_id')::uuid;
    v_qty := (v_item->>'qty')::integer;

    select * into v_prod from products where id = v_pid and status = 'active' for update;
    if not found then raise exception 'product % is unavailable', v_pid; end if;
    if v_qty < v_prod.moq then
      raise exception 'qty % below MOQ % for %', v_qty, v_prod.moq, v_prod.product_code; end if;
    if v_prod.sale_mode = 'carton_only' and (v_qty % v_prod.units_per_carton) <> 0 then
      raise exception 'qty % must be a multiple of carton (%) for %',
        v_qty, v_prod.units_per_carton, v_prod.product_code; end if;
    if v_qty > v_prod.available_qty then
      raise exception 'insufficient stock for %', v_prod.product_code; end if;

    v_sell := compute_selling_price(v_pid);

    select id into v_so from supplier_orders
      where order_id = v_order and supplier_id = v_prod.supplier_id;
    if v_so is null then
      insert into supplier_orders(order_id, supplier_id) values (v_order, v_prod.supplier_id)
        returning id into v_so;
    end if;

    insert into order_items(order_id, supplier_order_id, product_id, supplier_id, qty_ordered,
      buyer_unit_price, supplier_unit_price, units_per_carton_snapshot, sale_mode_snapshot,
      line_total_buyer, line_total_supplier)
    values (v_order, v_so, v_pid, v_prod.supplier_id, v_qty,
      v_sell, v_prod.supplier_price, v_prod.units_per_carton, v_prod.sale_mode,
      round(v_sell * v_qty, 2), round(v_prod.supplier_price * v_qty, 2));

    update products set available_qty = available_qty - v_qty where id = v_pid;
    v_subtotal := v_subtotal + round(v_sell * v_qty, 2);
  end loop;

  update supplier_orders so
     set total_supplier_value = (select coalesce(sum(line_total_supplier), 0)
                                 from order_items oi where oi.supplier_order_id = so.id)
   where so.order_id = v_order;

  update orders
     set subtotal = v_subtotal,
         total_amount = v_subtotal + extra_charges,
         status = 'sent_to_supplier'
   where id = v_order;

  -- buyer owes the System the order total (negative = owes)
  insert into ledger_entries(party_type, party_id, order_id, type, amount, note)
  values ('buyer', v_buyer, v_order, 'order_charge', -v_subtotal, 'Order placed');

  -- buyer's payment at checkout -> PENDING until the admin confirms it
  if p_payment_amount is not null and p_payment_amount > 0 then
    insert into payments(party_type, party_id, order_id, amount, direction, mode, status, entered_by, note)
    values ('buyer', v_buyer, v_order, p_payment_amount, 'in',
            coalesce(p_payment_mode, 'upi_qr')::payment_mode, 'pending', auth.uid(),
            'Buyer payment at checkout');
  end if;

  return v_order;
end $$;

grant execute on function place_order(jsonb, text, numeric, text) to authenticated;

-- ---------------------------------------------------------------------------
-- Admin confirms / rejects a buyer's checkout payment.
-- ---------------------------------------------------------------------------
create or replace function confirm_payment(p_payment_id uuid, p_confirm boolean default true) returns void
language plpgsql security definer set search_path = public as $$
begin
  if not is_admin() then raise exception 'admin only'; end if;
  update payments
     set status = case when p_confirm then 'confirmed'::payment_status else 'rejected'::payment_status end
   where id = p_payment_id;
end $$;

grant execute on function confirm_payment(uuid, boolean) to authenticated;
