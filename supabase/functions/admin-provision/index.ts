// Edge Function: admin-provision
// Creates supplier/buyer LOGIN accounts (mobile + PIN) and resets PINs.
// Only an admin may call it. Runs with the service_role key (server-side only).
//
// Login model: users sign in with mobile + PIN. We map the mobile to an internal
// email `<mobile>@<LOGIN_DOMAIN>` so we never need an SMS provider. The buyer/supplier
// apps must use the SAME domain when signing in. Real contact numbers live in the
// *_phones tables; this is purely the auth identity.
//
// Deploy via the Supabase dashboard (Edge Functions -> create) or the CLI.
// SUPABASE_URL / SUPABASE_ANON_KEY / SUPABASE_SERVICE_ROLE_KEY are injected by Supabase.

import { createClient } from 'jsr:@supabase/supabase-js@2';

const LOGIN_DOMAIN = 'randomdistributors.app';

const cors = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
  'Access-Control-Allow-Methods': 'POST, OPTIONS',
};

function json(body: unknown, status = 200) {
  return new Response(JSON.stringify(body), {
    status,
    headers: { ...cors, 'Content-Type': 'application/json' },
  });
}

function loginEmail(mobile: string) {
  return `${mobile.replace(/[^0-9]/g, '')}@${LOGIN_DOMAIN}`;
}

Deno.serve(async (req) => {
  if (req.method === 'OPTIONS') return new Response('ok', { headers: cors });
  if (req.method !== 'POST') return json({ error: 'method not allowed' }, 405);

  const url = Deno.env.get('SUPABASE_URL')!;
  const anonKey = Deno.env.get('SUPABASE_ANON_KEY')!;
  const serviceKey = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!;

  const authHeader = req.headers.get('Authorization') ?? '';
  const admin = createClient(url, serviceKey);

  // Verify the caller is an authenticated admin.
  const caller = createClient(url, anonKey, {
    global: { headers: { Authorization: authHeader } },
  });
  const { data: userData } = await caller.auth.getUser();
  const uid = userData.user?.id;
  if (!uid) return json({ error: 'not authenticated' }, 401);

  const { data: prof } = await admin.from('profiles').select('role').eq('id', uid).maybeSingle();
  if (prof?.role !== 'admin') return json({ error: 'admin only' }, 403);

  let body: Record<string, unknown>;
  try {
    body = await req.json();
  } catch {
    return json({ error: 'invalid JSON' }, 400);
  }

  const action = body.action as string;

  try {
    if (action === 'create_party') {
      const role = body.role as string; // 'supplier' | 'buyer'
      const mobile = String(body.mobile ?? '').trim();
      const pin = String(body.pin ?? '').trim();
      const name = String(body.name ?? '').trim();
      if (!['supplier', 'buyer'].includes(role) || !mobile || pin.length < 4 || !name) {
        return json({ error: 'role, mobile, name and a 4+ digit PIN are required' }, 400);
      }

      // 1. create the auth user (email = mobile@domain, confirmed, no SMS)
      const { data: created, error: cErr } = await admin.auth.admin.createUser({
        email: loginEmail(mobile),
        password: pin,
        email_confirm: true,
        user_metadata: { mobile, role, name },
      });
      if (cErr || !created.user) {
        return json({ error: `could not create login: ${cErr?.message ?? 'unknown'}` }, 400);
      }
      const newId = created.user.id;

      // 2. profile
      const { error: pErr } = await admin.from('profiles').insert({
        id: newId, role, email: loginEmail(mobile),
      });
      if (pErr) {
        await admin.auth.admin.deleteUser(newId); // roll back the auth user
        return json({ error: `profile failed: ${pErr.message}` }, 400);
      }

      // 3. party record + primary phone
      const table = role === 'supplier' ? 'suppliers' : 'buyers';
      const { data: party, error: partyErr } = await admin
        .from(table)
        .insert({
          profile_id: newId,
          name,
          business_name: body.business_name ?? null,
          address: body.address ?? null,
          ...(role === 'supplier' ? { gst_no: body.gst_no ?? null } : {}),
        })
        .select('id')
        .single();
      if (partyErr) {
        await admin.auth.admin.deleteUser(newId);
        return json({ error: `record failed: ${partyErr.message}` }, 400);
      }

      const phoneTable = role === 'supplier' ? 'supplier_phones' : 'buyer_phones';
      const fk = role === 'supplier' ? 'supplier_id' : 'buyer_id';
      await admin.from(phoneTable).insert({
        [fk]: party.id, phone: mobile, is_primary: true, whatsapp_enabled: true,
      });

      return json({ ok: true, user_id: newId, party_id: party.id });
    }

    if (action === 'reset_pin') {
      const userId = String(body.user_id ?? '');
      const pin = String(body.pin ?? '').trim();
      if (!userId || pin.length < 4) return json({ error: 'user_id and a 4+ digit PIN required' }, 400);
      const { error } = await admin.auth.admin.updateUserById(userId, { password: pin });
      if (error) return json({ error: error.message }, 400);
      return json({ ok: true });
    }

    return json({ error: 'unknown action' }, 400);
  } catch (e) {
    return json({ error: `${e}` }, 500);
  }
});
