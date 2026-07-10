# Admin panel (React)

The System/Admin console — full visibility of both sides.

**Screens:** dashboard, suppliers & buyers (provision accounts), products/moderation,
categories & brands, **margin setup** (supplier/category/product/override with live
preview), orders (both prices), payments entry (cash/UPI-QR/bank/online + proof),
settlement (dispatched vs received, margin, buyer wallet), communication (WhatsApp/push
via the admin number), settings.

**Stack:** React + Vite + TypeScript, Supabase JS client. Consider Refine or React-Admin
to generate the data-heavy CRUD quickly. Hosted free on Cloudflare Pages / Vercel.

> Requires **Node 20 LTS**. The Node on the build machine is currently v6 and must be
> upgraded before `npm install`. See [`../docs/SETUP.md`](../docs/SETUP.md).

**Scaffolding (next phase):** `npm create vite@latest admin -- --template react-ts`, add
`@supabase/supabase-js`. The admin uses the anon key for auth'd admin calls (RLS grants
admin full access); the service_role key is only for any server-side batch jobs, never in
the browser bundle.
