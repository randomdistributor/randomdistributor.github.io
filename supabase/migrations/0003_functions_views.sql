-- Random Distributors — business logic: margin engine, wall-preserving views,
-- checkout, payments->ledger, wallet, settlement. Apply after 0002.
--
-- Views here bypass base-table RLS on purpose (security_invoker = false) because a
-- buyer has NO row access to products/order_items; the view's WHERE clause + column
-- projection is what enforces the wall. Each view is gated with is_buyer()/is_supplier().

-- ---------------------------------------------------------------------------
-- Margin engine: selling price = supplier price + resolved margin
-- resolution order (most specific first): product_override > product > category > supplier
-- ---------------------------------------------------------------------------
create or replace function compute_selling_price(p_product_id uuid) returns numeric
language plpgsql stable security definer set search_path = public as $$
declare
  v_supplier_price numeric(14,2);
  v_supplier uuid;
  v_category uuid;
  r record;
  v_found boolean := false;
  v_type margin_type;
  v_val  numeric(14,2);
begin
  select supplier_price, supplier_id, category_id
    into v_supplier_price, v_supplier, v_category
  from products where id = p_product_id;
  if v_supplier_price is null then return null; end if;

  for r in
    select margin_type, margin_value from margin_rules
    where active and (
      (scope = 'product_override' and scope_ref_id = p_product_id) or
      (scope = 'product'          and scope_ref_id = p_product_id) or
      (scope = 'category'         and scope_ref_id = v_category)    or
      (scope = 'supplier'         and scope_ref_id = v_supplier)
    )
    order by case scope
      when 'product_override' then 1 when 'product' then 2
      when 'category' then 3 when 'supplier' then 4 end
    limit 1
  loop
    v_type := r.margin_type; v_val := r.margin_value; v_found := true;
  end loop;

  if not v_found then
    return v_supplier_price;   -- no margin configured; admin should set one
  elsif v_type = 'percent' then
    return round(v_supplier_price * (1 + v_val / 100.0), 2);
  else
    return round(v_supplier_price + v_val, 2);
  end if;
end $$;

-- ---------------------------------------------------------------------------
-- Buyer catalog view — selling price only, NO supplier price/identity
-- ---------------------------------------------------------------------------
create or replace view buyer_catalog with (security_invoker = false) as
  select
    p.id,
    p.product_code,
    p.description,
    p.category_id,
    c.name              as category_name,
    p.brand_id,
    b.name              as brand_name,
    p.unit,
    p.available_qty,
    p.units_per_carton,
    p.sale_mode,
    p.moq,
    compute_selling_price(p.id) as selling_price,
    (select url from product_images pi where pi.product_id = p.id
       order by is_primary desc, sort_order asc limit 1) as primary_image_url
  from products p
  left join categories c on c.id = p.category_id
  left join brands b     on b.id = p.brand_id
  where p.status = 'active' and (is_buyer() or is_admin());

grant select on buyer_catalog to authenticated;

-- ---------------------------------------------------------------------------
-- Buyer order items — buyer-side columns only (no supplier price/id)
-- ---------------------------------------------------------------------------
create or replace view buyer_order_items with (security_invoker = false) as
  select
    oi.id, oi.order_id, oi.product_id, oi.qty_ordered,
    oi.buyer_unit_price, oi.line_total_buyer,
    oi.units_per_carton_snapshot, oi.sale_mode_snapshot,
    p.product_code, p.description
  from order_items oi
  join orders o on o.id = oi.order_id
  join products p on p.id = oi.product_id
  where is_admin() or o.buyer_id = current_buyer_id();

grant select on buyer_order_items to authenticated;

-- ---------------------------------------------------------------------------
-- Supplier order items — supplier-side columns only (no selling price/margin)
-- ---------------------------------------------------------------------------
create or replace view supplier_order_items with (security_invoker = false) as
  select
    oi.id, oi.supplier_order_id, oi.product_id, oi.qty_ordered,
    oi.supplier_unit_price, oi.line_total_supplier,
    oi.units_per_carton_snapshot, oi.sale_mode_snapshot,
    p.product_code, p.description
  from order_items oi
  join products p on p.id = oi.product_id
  where is_admin() or oi.supplier_id = current_supplier_id();

grant select on supplier_order_items to authenticated;

-- ---------------------------------------------------------------------------
-- Buyer-safe dispatch view — hides the commercial dispatch BILL (which would
-- reveal supplier identity/price). Buyer sees status + the delivery/packing copy.
-- ---------------------------------------------------------------------------
create or replace view buyer_dispatches with (security_invoker = false) as
  select
    d.id, d.dispatch_no, d.supplier_order_id, so.order_id,
    d.status, d.dispatch_date, d.dispatch_copy_image_url, d.notes
  from dispatches d
  join supplier_orders so on so.id = d.supplier_order_id
  join orders o on o.id = so.order_id
  where is_admin() or o.buyer_id = current_buyer_id();

grant select on buyer_dispatches to authenticated;

create or replace view buyer_dispatch_items with (security_invoker = false) as
  select
    di.id, di.dispatch_id, di.order_item_id, di.qty_dispatched,
    p.product_code, p.description
  from dispatch_items di
  join order_items oi on oi.id = di.order_item_id
  join orders o on o.id = oi.order_id
  join products p on p.id = oi.product_id
  where is_admin() or o.buyer_id = current_buyer_id();

grant select on buyer_dispatch_items to authenticated;

-- ---------------------------------------------------------------------------
-- Account balances (wallet). security_invoker = true so ledger RLS applies:
-- each party sees only its own balance; admin sees all.
-- Sign convention: + = party's credit with the System; - = party owes the System.
-- ---------------------------------------------------------------------------
create or replace view party_balances with (security_invoker = true) as
  select party_type, party_id, coalesce(sum(amount), 0) as balance
  from ledger_entries
  group by party_type, party_id;

grant select on party_balances to authenticated;

-- ---------------------------------------------------------------------------
-- Payment -> ledger trigger
--   direction 'in'  = party paid the System  -> +amount (credit)
--   direction 'out' = System paid the party  -> -amount (reduces payable)
-- ---------------------------------------------------------------------------
create or replace function payment_to_ledger() returns trigger
language plpgsql security definer set search_path = public as $$
begin
  insert into ledger_entries(party_type, party_id, order_id, type, amount, ref_payment_id, note)
  values (
    new.party_type, new.party_id, new.order_id,
    (case when new.direction = 'in' then 'payment_in' else 'payment_out' end)::ledger_type,
    case when new.direction = 'in' then new.amount else -new.amount end,
    new.id, new.note
  );
  return new;
end $$;

drop trigger if exists t_payment_to_ledger on payments;
create trigger t_payment_to_ledger after insert on payments
  for each row execute function payment_to_ledger();

-- ---------------------------------------------------------------------------
-- Checkout: place_order(items) — the ONLY way a buyer creates an order.
-- Runs as definer so pricing/supplier data stay server-side (buyer never touches them).
-- items = jsonb array of { "product_id": uuid, "qty": int }
-- ---------------------------------------------------------------------------
create or replace function place_order(p_items jsonb, p_note text default null) returns uuid
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

  -- buyer now owes the System the order total (negative = owes)
  insert into ledger_entries(party_type, party_id, order_id, type, amount, note)
  values ('buyer', v_buyer, v_order, 'order_charge', -v_subtotal, 'Order placed');

  return v_order;
end $$;

grant execute on function place_order(jsonb, text) to authenticated;

-- ---------------------------------------------------------------------------
-- Settlement (admin): settle supplier on DISPATCHED value, buyer on RECEIVED value.
-- Admin absorbs the gap; buyer overpayment becomes wallet credit.
-- Verify against real data before going live (see docs/PROGRESS.md).
-- ---------------------------------------------------------------------------
create or replace function settle_order(p_order_id uuid) returns void
language plpgsql security definer set search_path = public as $$
declare
  v_buyer uuid;
  v_extra numeric(14,2);
  v_subtotal numeric(14,2);
  v_received_value numeric(14,2) := 0;
  v_dispatched_total numeric(14,2) := 0;
  so record;
  v_disp numeric(14,2);
begin
  if not is_admin() then raise exception 'admin only'; end if;

  select buyer_id, extra_charges, subtotal into v_buyer, v_extra, v_subtotal
  from orders where id = p_order_id;
  if v_buyer is null then raise exception 'order not found'; end if;

  -- buyer received value = confirmed received qty * buyer unit price
  select coalesce(sum(ri.qty_received * oi.buyer_unit_price), 0) into v_received_value
  from receipt_items ri
  join order_items oi on oi.id = ri.order_item_id
  where oi.order_id = p_order_id;

  -- per-supplier: dispatched value -> settlement + supplier ledger credit
  for so in select * from supplier_orders where order_id = p_order_id loop
    select coalesce(sum(di.qty_dispatched * di.unit_price), 0) into v_disp
    from dispatch_items di
    join dispatches d on d.id = di.dispatch_id
    where d.supplier_order_id = so.id;

    v_dispatched_total := v_dispatched_total + v_disp;

    insert into settlements(order_id, supplier_id, supplier_payable, buyer_final_amount, admin_margin_earned, settled_at)
    values (p_order_id, so.supplier_id, v_disp, 0, 0, now());

    if v_disp > 0 then
      insert into ledger_entries(party_type, party_id, order_id, type, amount, note)
      values ('supplier', so.supplier_id, p_order_id, 'settlement', v_disp, 'Settlement for dispatched goods');
    end if;
  end loop;

  -- buyer reconciliation: charged v_subtotal at checkout; final due = received + extra.
  -- refund the shortfall as credit (positive raises the buyer balance toward/above zero).
  insert into ledger_entries(party_type, party_id, order_id, type, amount, note)
  values ('buyer', v_buyer, p_order_id, 'settlement',
          (v_subtotal - v_received_value) - v_extra,
          'Order settlement: received-value reconciliation and extra charges');

  update settlements
     set buyer_final_amount = v_received_value + v_extra,
         admin_margin_earned = (v_received_value + v_extra) - v_dispatched_total
   where order_id = p_order_id;

  update orders set status = 'completed' where id = p_order_id;
end $$;

grant execute on function settle_order(uuid) to authenticated;
