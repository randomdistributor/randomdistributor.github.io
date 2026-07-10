# Data model

Explains the schema in [`../supabase/migrations`](../supabase/migrations). Read alongside
[`SPEC.md`](SPEC.md).

## Entity map

```
auth.users ──1:1── profiles ──┬── suppliers ──< supplier_phones
                              └── buyers    ──< buyer_phones

suppliers ──< products ──< product_images
products >── categories, brands
margin_rules   (scope: supplier | category | product | product_override)

buyers ──< orders ──< supplier_orders ──< order_items >── products
                          │
                          └──< dispatches ──< dispatch_items >── order_items
orders ──< receipts ──< receipt_items >── order_items

payments ─trigger─> ledger_entries      (per party; wallet = SUM)
settlements (per order/supplier)
notifications, audit_log
```

## How the wall is enforced (important)

RLS is **row**-level, but two of our secrets are **column**-level:

- buyers must not see `products.supplier_price` or supplier identity;
- suppliers must not see the selling price / margin on `order_items`.

You cannot hide a column with a row policy. So the pattern is:

1. **Base tables that mix both sides' data are admin-only** (`order_items`,
   `dispatch_items`) or owner-scoped where safe (`products` for its own supplier).
2. **Each side reads through a security-definer view** that projects only its permitted
   columns and filters to its own rows:
   - `buyer_catalog` — products with `selling_price`, no supplier price/id.
   - `buyer_order_items` — buyer columns only.
   - `supplier_order_items` — supplier columns only.
   - `buyer_dispatches` / `buyer_dispatch_items` — status + delivery copy, **not** the
     commercial dispatch bill (which would reveal the supplier).
3. **Buyer writes go through `place_order()`** (security definer), never direct inserts —
   so the buyer client never handles supplier price or margin.

> Rule of thumb: any new table holding cross-party data ships admin-only + a per-side
> view. Never expose a mixed-column table straight to a non-admin role.

## Money & sign convention

`ledger_entries.amount` is signed **from the party's perspective**:

- `+` = the party has credit with the System (paid in advance / System owes them)
- `-` = the party owes the System

Examples:
- Buyer places a ₹11,760 order → `order_charge -11,760`.
- Buyer pays the System ₹11,760 (admin records payment `in`) → `payment_in +11,760` (bal 0).
- Goods dispatched worth ₹9,480 → supplier `settlement +9,480` (System owes supplier).
- System pays supplier (payment `out`) → `payment_out -9,480` (bal 0).
- Buyer received only ₹10,520 of goods → settlement credits the ₹1,240 shortfall back →
  buyer balance `+1,240` = **wallet credit**.

`party_balances` view = `SUM(amount)` per party (respects RLS: each party sees only its own).

## Margin resolution

`compute_selling_price(product_id)` picks the single most specific active rule:
`product_override → product → category → supplier`, then applies percent or flat, rounded
to 2 dp. No rule configured → returns supplier price unchanged (admin should set a rule).

## MOQ / carton enforcement

Enforced in three places (defence in depth):
1. `order_items` CHECK: `carton_only` ⇒ `qty % units_per_carton = 0`.
2. `place_order()` raises on `qty < moq` or bad carton multiple, before writing.
3. The client disables invalid quantities in the UI.

Packaging is snapshotted onto `order_items` (`units_per_carton_snapshot`,
`sale_mode_snapshot`) so later product edits don't rewrite past orders.

## Order lifecycle

`created` (place_order builds it) → `sent_to_supplier` (checkout complete) →
`partially_dispatched` / `fully_dispatched` (supplier dispatches) →
`partially_received` (buyer confirms) → `completed` (settle_order) | `cancelled`.

Status transitions beyond checkout are driven by the admin/app as dispatches and receipts
are recorded (a future migration can add triggers to advance status automatically).
