import { createClient } from 'https://esm.sh/@supabase/supabase-js@2'

const corsHeaders = {
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
  'Access-Control-Allow-Methods': 'POST, OPTIONS',
}

// ---- APNs JWT helpers (mirrors check-heartbeats) ----

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

async function sendModePush(deviceToken: string, mode: string): Promise<void> {
  const teamId = Deno.env.get('APNS_TEAM_ID')
  const keyId = Deno.env.get('APNS_KEY_ID')
  const privateKey = Deno.env.get('APNS_KEY')
  const bundleId = Deno.env.get('APNS_BUNDLE_ID')

  if (!teamId || !keyId || !privateKey || !bundleId) {
    console.warn('⚠️ APNs not configured — skipping mode push')
    return
  }

  // Visible alert push: silent (background) pushes are heavily throttled on
  // watchOS and frequently never wake the suspended app. A visible alert is
  // the only reliable way to flip modes "within seconds" of the caregiver
  // tapping save. content-available: 1 also fires didReceiveRemoteNotification
  // so the app refetches settings the moment it wakes.
  const modeLabel = mode === 'custom' ? 'SafeLoop Fall Detection' : 'Apple Fall Detection'
  const jwt = await createAPNsJWT(teamId, keyId, privateKey)
  const apnsRes = await fetch(`https://api.push.apple.com/3/device/${deviceToken}`, {
    method: 'POST',
    headers: {
      'authorization': `bearer ${jwt}`,
      'apns-push-type': 'alert',
      'apns-priority': '10',
      'apns-topic': bundleId,
      'content-type': 'application/json',
    },
    body: JSON.stringify({
      aps: {
        alert: {
          title: 'SafeLoop',
          body: `Switched to ${modeLabel}`,
        },
        sound: 'default',
        'content-available': 1,
      },
      type: 'fall_mode_changed',
      mode,
    }),
  })
  const apnsBody = await apnsRes.text()
  console.log(`🍎 APNs mode push: ${apnsRes.status} ${apnsBody}`)
}

Deno.serve(async (req) => {
  if (req.method === 'OPTIONS') {
    return new Response('ok', { headers: corsHeaders })
  }

  try {
    const { wearer_id, mode } = await req.json()
    if (!wearer_id || !mode) {
      return new Response(JSON.stringify({ error: 'wearer_id and mode required' }), {
        status: 400, headers: { ...corsHeaders, 'Content-Type': 'application/json' }
      })
    }
    if (mode !== 'apple' && mode !== 'custom') {
      return new Response(JSON.stringify({ error: 'mode must be apple or custom' }), {
        status: 400, headers: { ...corsHeaders, 'Content-Type': 'application/json' }
      })
    }

    // Apply the update under the caller's JWT so the existing
    // "Caregiver admins can manage wearers" RLS policy enforces auth.
    const authHeader = req.headers.get('Authorization')
    const userClient = createClient(
      Deno.env.get('SUPABASE_URL')!,
      Deno.env.get('SUPABASE_ANON_KEY')!,
      { global: { headers: { Authorization: authHeader ?? '' } } }
    )

    const { error: updateError } = await userClient
      .from('wearers')
      .update({ fall_detection_mode: mode })
      .eq('id', wearer_id)

    if (updateError) {
      return new Response(JSON.stringify({ error: updateError.message }), {
        status: 403, headers: { ...corsHeaders, 'Content-Type': 'application/json' }
      })
    }

    // Push lookup uses service role: caregivers don't have read access to
    // watch_heartbeats, and the device/wearer link is safe to traverse.
    const adminClient = createClient(
      Deno.env.get('SUPABASE_URL')!,
      Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!
    )

    const { data: device } = await adminClient
      .from('devices')
      .select('seven_digit_code')
      .eq('wearer_id', wearer_id)
      .maybeSingle()

    if (device?.seven_digit_code) {
      const { data: heartbeat } = await adminClient
        .from('watch_heartbeats')
        .select('push_token')
        .eq('wearer_device_id', device.seven_digit_code)
        .maybeSingle()

      if (heartbeat?.push_token) {
        await sendModePush(heartbeat.push_token, mode)
      } else {
        console.log('ℹ️ No watch push token yet — watch will refetch on next foreground')
      }
    } else {
      console.log('ℹ️ No device linked to wearer yet — skipping push')
    }

    return new Response(JSON.stringify({ ok: true }), {
      headers: { ...corsHeaders, 'Content-Type': 'application/json' }
    })
  } catch (error) {
    console.error('❌ set-fall-detection-mode error:', error)
    return new Response(JSON.stringify({ error: error.message }), {
      status: 500, headers: { ...corsHeaders, 'Content-Type': 'application/json' }
    })
  }
})
