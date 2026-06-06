import { createClient } from 'https://esm.sh/@supabase/supabase-js@2'

const corsHeaders = {
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
  'Access-Control-Allow-Methods': 'POST, OPTIONS',
}

Deno.serve(async (req) => {
  if (req.method === 'OPTIONS') {
    return new Response('ok', { headers: corsHeaders })
  }

  try {
    const { target_user_id, new_user_type } = await req.json() as {
      target_user_id?: string
      new_user_type?: 'caregiver' | 'caregiver_admin'
    }

    if (!target_user_id || !new_user_type) {
      return new Response(
        JSON.stringify({ error: 'target_user_id and new_user_type required' }),
        { status: 400, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
      )
    }

    // Use the caller's JWT so the RPC's is_caregiver_admin() / auth.uid()
    // checks operate on the actual caller. The RPC enforces same-account and
    // protects against demoting the last admin.
    const authHeader = req.headers.get('Authorization')
    const userClient = createClient(
      Deno.env.get('SUPABASE_URL')!,
      Deno.env.get('SUPABASE_ANON_KEY')!,
      { global: { headers: { Authorization: authHeader ?? '' } } }
    )

    const { error } = await userClient.rpc('update_caregiver_role', {
      p_target_user_id: target_user_id,
      p_new_user_type: new_user_type,
    })

    if (error) {
      const status = /admin/i.test(error.message) ? 403 : 400
      return new Response(
        JSON.stringify({ error: error.message }),
        { status, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
      )
    }

    return new Response(
      JSON.stringify({ ok: true }),
      { headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
    )
  } catch (error) {
    console.error('❌ update-caregiver-role error:', error)
    return new Response(
      JSON.stringify({ error: (error as Error).message }),
      { status: 500, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
    )
  }
})
