import { createClient } from 'https://esm.sh/@supabase/supabase-js@2'

const corsHeaders = {
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
}

const VALID_BATTERY_STATES = new Set(['unknown', 'unplugged', 'charging', 'full'])

Deno.serve(async (req) => {
  if (req.method === 'OPTIONS') {
    return new Response('ok', { headers: corsHeaders })
  }

  try {
    const { wearer_device_id, timestamp, push_token, battery_level, battery_state } = await req.json()

    if (!wearer_device_id) {
      return new Response(JSON.stringify({ error: 'wearer_device_id required' }), {
        status: 400, headers: { ...corsHeaders, 'Content-Type': 'application/json' }
      })
    }

    const supabase = createClient(
      Deno.env.get('SUPABASE_URL')!,
      Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!
    )

    const seenAt = timestamp ?? new Date().toISOString()

    const upsertData: Record<string, unknown> = {
      wearer_device_id,
      last_seen: seenAt,
      alert_sent_at: null, // reset so next stale period triggers a fresh notification
    }

    if (push_token) {
      upsertData.push_token = push_token
    }

    const { error } = await supabase
      .from('watch_heartbeats')
      .upsert(upsertData, { onConflict: 'wearer_device_id' })

    if (error) throw error

    // Mirror freshness + battery onto the devices row so the Care app's
    // existing wearer query (which already selects devices.last_seen) reflects
    // the watch heartbeat without a separate join.
    const deviceUpdate: Record<string, unknown> = { last_seen: seenAt }
    if (typeof battery_level === 'number' && battery_level >= 0 && battery_level <= 100) {
      deviceUpdate.battery_level = Math.round(battery_level)
    }
    if (typeof battery_state === 'string' && VALID_BATTERY_STATES.has(battery_state)) {
      deviceUpdate.battery_state = battery_state
    }

    const { error: deviceError } = await supabase
      .from('devices')
      .update(deviceUpdate)
      .eq('seven_digit_code', wearer_device_id)

    if (deviceError) {
      // Don't fail the heartbeat — the watch_heartbeats upsert is the
      // authoritative liveness signal. Just log and move on.
      console.error('⚠️ devices update failed (heartbeat still recorded):', deviceError)
    }

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
