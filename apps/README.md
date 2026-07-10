# Flutter apps

Two Flutter apps share the same backend (Supabase) and the same design language:

- `buyer/` — catalog, product detail (MOQ/carton), cart, checkout, orders, receipt
  confirmation, wallet. Reads `buyer_catalog`, `buyer_order_items`, `buyer_dispatches`;
  checks out via the `place_order` RPC.
- `supplier/` — products (with image upload), incoming "System" orders, dispatch (multi /
  short supply, bill + copy upload), account. Reads `supplier_order_items`; writes its own
  `products`, `dispatches`, `dispatch_items`.

Neither app ever queries the other side's data — the wall is enforced server-side by RLS,
and these apps only ever hit the per-side views/RPCs.

**Scaffolding (next phase):** `flutter create buyer` / `flutter create supplier`, add
`supabase_flutter`, `image_picker`, `flutter_image_compress`, `firebase_messaging`, and
`google_mlkit_text_recognition` (optional OCR pre-fill). Config reads `SUPABASE_URL` /
`SUPABASE_ANON_KEY` via `--dart-define`.
