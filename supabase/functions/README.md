# Supabase Edge Functions

## `admin-provision`

Creates supplier/buyer **login accounts** (mobile + PIN) and resets PINs. Only an admin
can call it. It runs server-side with the `service_role` key, which is why account
creation can't be done directly from the app.

### Login model
Users sign in with **mobile + PIN**. The function maps the mobile to an internal email
`<digits>@randomdistributors.app` and creates a pre-confirmed user — so **no SMS provider
is required**. The buyer/supplier apps must sign in with the *same* mapping:

```
email    = <mobile digits> + '@randomdistributors.app'
password = PIN
```

If you change `LOGIN_DOMAIN` in `index.ts`, change it in the apps too.

### Deploy without the CLI (dashboard)
1. Supabase dashboard → **Edge Functions** → **Create a function**.
2. Name it exactly `admin-provision`.
3. Paste the contents of `admin-provision/index.ts` into the editor.
4. **Deploy**. (`SUPABASE_URL`, `SUPABASE_ANON_KEY`, `SUPABASE_SERVICE_ROLE_KEY` are
   injected automatically — you don't set them.)

### Deploy with the CLI (optional, later)
```
supabase functions deploy admin-provision
```

### Test
In the admin panel → Suppliers/Buyers → **Add** → fill name, mobile, PIN → Create.
A new login is created; the supplier/buyer can then sign in on their app with that
mobile + PIN. Use the row's **⋮ → Reset PIN** to change it.
