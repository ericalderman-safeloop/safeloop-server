import { createClient } from 'https://esm.sh/@supabase/supabase-js@2'

const corsHeaders = {
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
}

// ---- APNs JWT helpers ----

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

async function sendWatchPush(deviceToken: string, message: string): Promise<void> {
  const teamId = Deno.env.get('APNS_TEAM_ID')
  const keyId = Deno.env.get('APNS_KEY_ID')
  const privateKey = Deno.env.get('APNS_KEY')
  const bundleId = Deno.env.get('APNS_BUNDLE_ID')

  if (!teamId || !keyId || !privateKey || !bundleId) {
    console.warn('⚠️ APNs not configured — skipping watch push')
    return
  }

  console.log(`🍎 Sending APNs push to token: ${deviceToken.slice(0, 8)}... bundle: ${bundleId}`)
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
          title: 'SafeLoop: Monitoring Stopped',
          body: message,
        },
        sound: 'default',
      },
    }),
  })
  const apnsBody = await apnsRes.text()
  console.log(`🍎 APNs response: ${apnsRes.status} ${apnsBody}`)
}

async function sendExpoPush(
  token: string,
  title: string,
  body: string,
  supabase?: ReturnType<typeof createClient>,
  userId?: string
): Promise<void> {
  const res = await fetch('https://exp.host/--/api/v2/push/send', {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify({ to: token, title, body, sound: 'default' }),
  })
  const result = await res.json()
  const ticket = result.data?.[0]
  if (ticket?.details?.error === 'DeviceNotRegistered' && supabase && userId) {
    console.log('⚠️ DeviceNotRegistered — clearing push token for user:', userId)
    await supabase.from('users').update({ apns_token: null, fcm_token: null }).eq('id', userId)
  } else {
    console.log(`📱 Expo push response (${res.status}):`, JSON.stringify(ticket))
  }
}

// ---- Main handler ----

Deno.serve(async (req) => {
  if (req.method === 'OPTIONS') {
    return new Response('ok', { headers: corsHeaders })
  }

  try {
    const supabase = createClient(
      Deno.env.get('SUPABASE_URL')!,
      Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!
    )

    // Find heartbeats stale >15 min that have never been alerted for this stale period.
    // alert_sent_at is reset to NULL by watch-heartbeat when the watch resumes, so once
    // we notify we stay silent until the watch comes back online and goes stale again.
    const { data: stale, error } = await supabase
      .from('watch_heartbeats')
      .select('wearer_device_id, push_token, alert_sent_at')
      .lt('last_seen', new Date(Date.now() - 12 * 60 * 1000).toISOString())
      .is('alert_sent_at', null)

    if (error) throw error
    if (!stale || stale.length === 0) {
      return new Response(JSON.stringify({ checked: true, stale: 0 }), {
        headers: { ...corsHeaders, 'Content-Type': 'application/json' }
      })
    }

    console.log(`🔍 Found ${stale.length} stale heartbeat(s)`)

    for (const heartbeat of stale) {
      const deviceId = heartbeat.wearer_device_id

      // 1. Push to watch if we have a token
      if (heartbeat.push_token) {
        await sendWatchPush(
          heartbeat.push_token,
          'Tap to restart fall monitoring'
        )
      }

      // 2. Find caregivers via device → wearer → caregiver_wearers
      const { data: caregivers } = await supabase
        .from('devices')
        .select(`
          wearers!inner (
            name,
            caregiver_wearer_assignments!inner (
              users!caregiver_user_id (
                id,
                apns_token,
                fcm_token,
                push_notifications_enabled
              )
            )
          )
        `)
        .eq('seven_digit_code', deviceId)
        .single()

      const wearerName = (caregivers?.wearers as any)?.name ?? 'your wearer'

      const caregiverUsers = (caregivers?.wearers as any)
        ?.caregiver_wearer_assignments
        ?.map((cw: any) => cw.users) ?? []

      for (const user of caregiverUsers) {
        const pushToken = user?.apns_token ?? user?.fcm_token
        if (pushToken && user?.push_notifications_enabled) {
          await sendExpoPush(
            pushToken,
            'SafeLoop Monitoring Stopped',
            `${wearerName}'s fall monitoring may have stopped. Check their watch.`,
            supabase,
            user.id
          )
        }
      }

      // 3. Mark alert sent
      await supabase
        .from('watch_heartbeats')
        .update({ alert_sent_at: new Date().toISOString() })
        .eq('wearer_device_id', deviceId)
    }

    return new Response(JSON.stringify({ checked: true, stale: stale.length }), {
      headers: { ...corsHeaders, 'Content-Type': 'application/json' }
    })

  } catch (error) {
    console.error('❌ check-heartbeats error:', error)
    return new Response(JSON.stringify({ error: error.message }), {
      status: 500, headers: { ...corsHeaders, 'Content-Type': 'application/json' }
    })
  }
})
