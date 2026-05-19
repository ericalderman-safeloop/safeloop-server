import { serve } from "https://deno.land/std@0.168.0/http/server.ts"
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2'

const corsHeaders = {
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
}

interface ResolvePayload {
  help_request_id: string
  status: 'resolved' | 'false_alarm'
  resolved_by_user_id?: string  // caregiver resolving
  notes?: string                 // caregiver notes at time of resolution
  wearer_device_id?: string      // watch cancel path
}

serve(async (req) => {
  if (req.method === 'OPTIONS') {
    return new Response('ok', { headers: corsHeaders })
  }

  try {
    const serviceClient = createClient(
      Deno.env.get('SUPABASE_URL') ?? '',
      Deno.env.get('SUPABASE_SERVICE_ROLE_KEY') ?? ''
    )

    const { help_request_id, status, notes, wearer_device_id } =
      await req.json() as ResolvePayload

    console.log('🔔 Resolving help request:', { help_request_id, status })

    let resolvedById: string | null = null

    // --- Update the help request ---

    if (wearer_device_id) {
      // Watch cancel path — DB function verifies device ownership
      const { error } = await serviceClient.rpc('cancel_help_request_from_watch', {
        p_help_request_id: help_request_id,
        p_wearer_device_id: wearer_device_id
      })
      if (error) throw error
    } else {
      // Caregiver resolution path — require authenticated user
      const authHeader = req.headers.get('Authorization')
      if (!authHeader) {
        return new Response(JSON.stringify({ success: false, error: 'Unauthorized' }), {
          headers: { ...corsHeaders, 'Content-Type': 'application/json' }, status: 401
        })
      }

      const { data: { user }, error: authError } = await serviceClient.auth.getUser(
        authHeader.replace('Bearer ', '')
      )
      if (authError || !user) {
        return new Response(JSON.stringify({ success: false, error: 'Unauthorized' }), {
          headers: { ...corsHeaders, 'Content-Type': 'application/json' }, status: 401
        })
      }

      resolvedById = user.id

      const updates: Record<string, unknown> = {
        event_status: status,
        resolved_at: new Date().toISOString(),
        resolved_by: user.id,
      }
      if (notes !== undefined) updates.notes = notes

      const { error } = await serviceClient
        .from('help_requests')
        .update(updates)
        .eq('id', help_request_id)
      if (error) throw error
    }

    console.log('✅ Help request updated to', status)

    // --- Get caregivers for notifications ---

    const { data: caregivers, error: caregiversError } = await serviceClient
      .rpc('get_caregivers_for_help_request', { p_help_request_id: help_request_id })

    if (caregiversError) {
      console.error('⚠️ Could not fetch caregivers:', caregiversError)
    }

    // --- Send push notifications ---

    const wearerName = caregivers?.[0]?.wearer_name ?? 'the wearer'
    const isFalseAlarm = status === 'false_alarm'

    const title = isFalseAlarm ? '⚠️ False Alarm' : '✅ Alert Resolved'
    const body = isFalseAlarm
      ? `${wearerName}'s alert was cancelled — false alarm.`
      : `${wearerName}'s alert has been resolved.`

    let notificationsSent = 0

    if (caregivers && caregivers.length > 0) {
      for (const caregiver of caregivers) {
        // Don't notify the caregiver who resolved it — they already know
        if (caregiver.user_id === resolvedById) continue

        const pushToken = caregiver.apns_token ?? caregiver.fcm_token
        if (pushToken && caregiver.push_notifications_enabled) {
          try {
            await sendExpoPushNotification(pushToken, title, body, help_request_id, status)
            notificationsSent++
          } catch (err) {
            console.error('⚠️ Push notification failed for', caregiver.user_id, err)
          }
        }
      }
    }

    console.log(`📱 Sent ${notificationsSent} resolution notifications`)

    return new Response(
      JSON.stringify({ success: true, notifications_sent: notificationsSent }),
      { headers: { ...corsHeaders, 'Content-Type': 'application/json' }, status: 200 }
    )

  } catch (error) {
    console.error('❌ resolve-help-request failed:', error)
    return new Response(
      JSON.stringify({ success: false, error: error.message }),
      { headers: { ...corsHeaders, 'Content-Type': 'application/json' }, status: 400 }
    )
  }
})

async function sendExpoPushNotification(
  token: string,
  title: string,
  body: string,
  helpRequestId: string,
  status: string
): Promise<void> {
  const response = await fetch('https://exp.host/--/api/v2/push/send', {
    method: 'POST',
    headers: {
      'Accept': 'application/json',
      'Content-Type': 'application/json',
    },
    body: JSON.stringify({
      to: token,
      sound: 'default',
      title,
      body,
      data: {
        type: 'alert_resolved',
        help_request_id: helpRequestId,
        status,
      },
      priority: 'high',
      channelId: 'emergency',
    })
  })

  const result = await response.json()
  if (result.data?.[0]?.status !== 'ok') {
    console.error('❌ Expo push failed:', result)
  }
}
