import { createClient } from 'https://esm.sh/@supabase/supabase-js@2'

const corsHeaders = {
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
  'Access-Control-Allow-Methods': 'POST, OPTIONS',
}

// ---- APNs JWT helpers (mirrors set-fall-detection-mode) ----

function pemToArrayBuffer(pem: string): ArrayBuffer {
  const base64 = pem
    .replace(/-----BEGIN PRIVATE KEY-----/g, '')
    .replace(/-----END PRIVATE KEY-----/g, '')
    .replace(/\s/g, '')
  const binary = atob(base64)
  const buffer = new Uint8Array(binary.length)
  for (let i = 0; i < binary.length; i++) buffer[i] = binary.charCodeAt(i)
  return buffer.buffer
}

function base64url(str: string): string {
  return btoa(str).replace(/\+/g, '-').replace(/\//g, '_').replace(/=/g, '')
}

async function createAPNsJWT(teamId: string, keyId: string, privateKeyPem: string): Promise<string> {
  const privateKey = await crypto.subtle.importKey(
    'pkcs8',
    pemToArrayBuffer(privateKeyPem),
    { name: 'ECDSA', namedCurve: 'P-256' },
    false,
    ['sign']
  )
  const now = Math.floor(Date.now() / 1000)
  const header = base64url(JSON.stringify({ alg: 'ES256', kid: keyId }))
  const payload = base64url(JSON.stringify({ iss: teamId, iat: now }))
  const sigInput = `${header}.${payload}`
  const sigBytes = await crypto.subtle.sign(
    { name: 'ECDSA', hash: 'SHA-256' },
    privateKey,
    new TextEncoder().encode(sigInput)
  )
  const sigBase64 = base64url(String.fromCharCode(...new Uint8Array(sigBytes)))
  return `${sigInput}.${sigBase64}`
}

async function sendSilentSettingsPush(deviceToken: string): Promise<void> {
  const teamId = Deno.env.get('APNS_TEAM_ID')
  const keyId = Deno.env.get('APNS_KEY_ID')
  const privateKey = Deno.env.get('APNS_KEY')
  const bundleId = Deno.env.get('APNS_BUNDLE_ID')

  if (!teamId || !keyId || !privateKey || !bundleId) {
    console.warn('⚠️ APNs not configured — skipping silent settings push')
    return
  }

  const jwt = await createAPNsJWT(teamId, keyId, privateKey)
  // Reuse the existing fall_mode_changed push type — the watch already
  // refetches all fall settings (mode + sensitivity) on this signal.
  const apnsRes = await fetch(`https://api.push.apple.com/3/device/${deviceToken}`, {
    method: 'POST',
    headers: {
      'authorization': `bearer ${jwt}`,
      'apns-push-type': 'background',
      'apns-priority': '5',
      'apns-topic': bundleId,
      'content-type': 'application/json',
    },
    body: JSON.stringify({
      aps: { 'content-available': 1 },
      type: 'fall_mode_changed',
    }),
  })
  const apnsBody = await apnsRes.text()
  console.log(`🍎 APNs silent push (sensitivity): ${apnsRes.status} ${apnsBody}`)
}

Deno.serve(async (req) => {
  if (req.method === 'OPTIONS') {
    return new Response('ok', { headers: corsHeaders })
  }

  try {
    const { wearer_device_id, sensitivity } = await req.json() as {
      wearer_device_id?: string
      sensitivity?: 'low' | 'medium' | 'high' | null
    }

    if (!wearer_device_id) {
      return new Response(JSON.stringify({ error: 'wearer_device_id required' }), {
        status: 400, headers: { ...corsHeaders, 'Content-Type': 'application/json' }
      })
    }
    if (sensitivity !== null && sensitivity !== 'low' && sensitivity !== 'medium' && sensitivity !== 'high') {
      return new Response(JSON.stringify({ error: 'sensitivity must be low|medium|high or null' }), {
        status: 400, headers: { ...corsHeaders, 'Content-Type': 'application/json' }
      })
    }

    const adminClient = createClient(
      Deno.env.get('SUPABASE_URL')!,
      Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!
    )

    if (sensitivity === null) {
      // Clearing a per-device override (not allowed for GLOBAL).
      if (wearer_device_id === 'GLOBAL') {
        return new Response(JSON.stringify({ error: 'cannot clear GLOBAL default' }), {
          status: 400, headers: { ...corsHeaders, 'Content-Type': 'application/json' }
        })
      }
      const { error } = await adminClient
        .from('fall_detection_settings')
        .delete()
        .eq('wearer_device_id', wearer_device_id)
      if (error) {
        return new Response(JSON.stringify({ error: error.message }), {
          status: 500, headers: { ...corsHeaders, 'Content-Type': 'application/json' }
        })
      }
    } else {
      const { error } = await adminClient
        .from('fall_detection_settings')
        .upsert(
          { wearer_device_id, sensitivity, updated_at: new Date().toISOString() },
          { onConflict: 'wearer_device_id' }
        )
      if (error) {
        return new Response(JSON.stringify({ error: error.message }), {
          status: 500, headers: { ...corsHeaders, 'Content-Type': 'application/json' }
        })
      }
    }

    // Push notification: only for per-device updates. For GLOBAL changes we
    // skip — the affected wearers are the ones without per-device overrides,
    // and they'll pick up the new value on next foreground or watch refetch.
    if (wearer_device_id !== 'GLOBAL') {
      const { data: heartbeat } = await adminClient
        .from('watch_heartbeats')
        .select('push_token')
        .eq('wearer_device_id', wearer_device_id)
        .maybeSingle()

      if (heartbeat?.push_token) {
        await sendSilentSettingsPush(heartbeat.push_token)
      } else {
        console.log('ℹ️ No watch push token yet — watch will refetch on next foreground')
      }
    }

    return new Response(JSON.stringify({ ok: true }), {
      headers: { ...corsHeaders, 'Content-Type': 'application/json' }
    })
  } catch (error) {
    console.error('❌ set-fall-detection-sensitivity error:', error)
    return new Response(JSON.stringify({ error: (error as Error).message }), {
      status: 500, headers: { ...corsHeaders, 'Content-Type': 'application/json' }
    })
  }
})
