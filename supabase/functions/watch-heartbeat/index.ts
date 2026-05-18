import { serve } from "https://deno.land/std@0.168.0/http/server.ts"
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2'

const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
}

serve(async (req) => {
  if (req.method === 'OPTIONS') {
    return new Response('ok', { headers: corsHeaders })
  }

  try {
    const { wearer_device_id, timestamp, push_token } = await req.json()

    if (!wearer_device_id) {
      return new Response(JSON.stringify({ error: 'wearer_device_id required' }), {
        status: 400, headers: { ...corsHeaders, 'Content-Type': 'application/json' }
      })
    }

    const supabase = createClient(
      Deno.env.get('SUPABASE_URL')!,
      Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!
    )

    const upsertData: Record<string, unknown> = {
      wearer_device_id,
      last_seen: timestamp ?? new Date().toISOString(),
    }

    if (push_token) {
      upsertData.push_token = push_token
    }

    const { error } = await supabase
      .from('watch_heartbeats')
      .upsert(upsertData, { onConflict: 'wearer_device_id' })

    if (error) throw error

    return new Response(JSON.stringify({ ok: true }), {
      headers: { ...corsHeaders, 'Content-Type': 'application/json' }
    })

  } catch (error) {
    console.error('❌ watch-heartbeat error:', error)
    return new Response(JSON.stringify({ error: error.message }), {
      status: 500, headers: { ...corsHeaders, 'Content-Type': 'application/json' }
    })
  }
})
