# Random Distributors — Requirements Spec

This is the agreed specification captured from the planning discussion. It is the source
of truth for the data model and screens.

## 1. Actors

- **Admin (the "System")** — the middleman. Owns margins, money, communication, and both
  sides of every order. Has a display name and one primary contact number used to talk to
  both parties (WhatsApp / in-app; SMS optional later).
- **Supplier** — lists products at a supplier price; receives orders that appear to come
  from the System; packs and dispatches; is paid by the System.
- **Buyer** — browses the catalog by image; buys at the selling price; pays the System;
  confirms receipt.

Closed group: **no public signup.** Admin provisions accounts.

**Login model:** buyers and suppliers log in with **mobile number + PIN** (most users have
no email). To avoid paid SMS, the mobile is mapped internally to `<mobile>@<login-domain>`
so no SMS/phone-provider is needed; the admin sets an initial PIN (changeable). Real
contact numbers live in the `*_phones` tables. WhatsApp OTP ("login with OTP / forgot PIN")
is a planned later addition once the WhatsApp Business API is set up. The admin logs in with
a normal email + password. Account creation runs through the `admin-provision` Edge Function
(holds the service_role key server-side).

## 2. The privacy wall (non-negotiable)

- A supplier must never receive buyer identity, selling price, or margin.
- A buyer must never receive supplier identity or supplier price.
- Each side's only visible counterparty is the System.
- Enforced at the **database** level via Row Level Security, so an app bug cannot leak the
  other side's data. UI hiding alone is not sufficient.

## 3. Products & catalog

- Each product is bound to **exactly one supplier**.
- Fields: product code, description, category, brand, unit, available qty, supplier price,
  and one or more **images** (image is central; buyers purchase largely by image).
- **MOQ & carton rules (product level):**
  - `units_per_carton` — units in one carton.
  - `sale_mode` — `loose_allowed` or `carton_only`.
  - `moq` — minimum order quantity (in base units).
  - Validation: `qty >= moq`; if `carton_only`, `qty` must be a multiple of
    `units_per_carton` (buyer effectively picks cartons).
- Buyers filter by **brand** and **category**, and see available qty + selling price.

## 4. Pricing / margin engine

- **Selling price = supplier price + resolved margin.**
- Margin rules exist at four scopes; most specific wins:
  `product_override → product → category → supplier`.
- Margin can be **percent** or **flat**.
- Supplier price is never exposed to buyers; margin/selling price never to suppliers.

## 5. Ordering & fulfilment

1. Buyer adds one or more products (respecting MOQ/carton) to a cart and checks out.
2. An **order** is created (buyer-facing). It splits into one **supplier_order** per
   supplier — this is what each supplier sees, labelled as from the System.
3. Order can carry **extra charges** added by the Admin (added to the buyer bill).
4. Each supplier_order is notified to the supplier (push / WhatsApp).
5. A supplier fulfils via one or more **dispatches** (multiple shipments / short supply
   allowed), attaching a **dispatch copy** and **dispatch bill** image.
   - **Supplier's final qty & value = sum of what was dispatched.**
6. The buyer receives possibly across multiple dispatches and confirms **received qty**.
   - **Buyer's final qty & value = sum of what the buyer confirmed received.**
7. The Admin absorbs any gap between dispatched and received.

### Order status flow
`created → sent_to_supplier → partially_dispatched → fully_dispatched →
partially_received → completed` (or `cancelled`).

## 6. Money

- **No payment gateway.** The Admin records payments manually.
- Payment fields: party, order (optional), amount, direction (in/out), **mode**
  (cash / upi_qr / bank / online / adjustment), reference no, optional proof image.
- "Self QR": Admin shows their own UPI QR; buyer pays; Admin records the receipt.
- A **ledger** tracks every party's account; wallet balance is derived from it.
- Buyer pays the System at checkout. After both sides confirm, the System settles the
  supplier (on dispatched value) and reconciles the buyer (on received value).
- **Excess buyer payment → wallet credit**, carried forward.
- A payment gateway can be added later; it would simply create the same ledger entries
  automatically. No model change required.

## 7. Dispatch document reading (OCR) — optional assist

- The dispatch copy / bill **image is always stored and is the source of truth.**
- OCR is an *assist only, never an authority* (financial data is always human-confirmed):
  - Level 0 (baseline): store & display the image. A human reads it.
  - Level 1 (recommended): on-device OCR (Google ML Kit) **pre-fills** qty/amount; human
    confirms before saving.
  - Level 2 (later, optional): vision-AI structured extraction.
- Safe to attempt, safe to drop — the image + human confirmation cover correctness.

## 8. Communication

- Channels: in-app, push (FCM), WhatsApp (Business Cloud API). SMS optional/later.
- The Admin's single number is the only outbound sender identity to both parties.
- Multiple phone numbers per supplier and per buyer; one may be marked primary /
  WhatsApp-enabled.

## 9. Volume (drives the free-tier choices)

~1,000 products (with images — the only large data), <20 suppliers, ~100 buyers,
<100 orders / dispatches / payments per month.

## 10. Confirmed design decisions

1. One order can contain multiple suppliers; it splits into supplier_orders. ✔
2. A product belongs to exactly one supplier. ✔
3. Supplier settled on dispatched; buyer settled on received; Admin absorbs the gap. ✔
4. Excess buyer payment becomes wallet credit. ✔
5. Auth is email/password (no phone-OTP), no payment gateway, OCR optional. ✔
