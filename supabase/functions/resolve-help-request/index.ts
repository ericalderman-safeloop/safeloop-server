import { serve } from "https://deno.land/std@0.168.0/http/server.ts"
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2'

const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
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
    const supabase = createClient(
      Deno.env.get('SUPABASE_URL') ?? '',
      Deno.env.get('SUPABASE_SERVICE_ROLE_KEY') ?? ''
    )

    const { help_request_id, status, resolved_by_user_id, notes, wearer_device_id } =
      await req.json() as ResolvePayload

    console.log('🔔 Resolving help request:', { help_request_id, status })

    // --- Update the help request ---

    if (wearer_device_id) {
      // Watch cancel path — delegate to DB function which verifies device ownership
      // and appends the cancellation note
      const { error } = await supabase.rpc('cancel_help_request_from_watch', {
        p_help_request_id: help_request_id,
        p_wearer_device_id: wearer_device_id
      })
      if (error) throw error
    } else {
      // Caregiver resolution path
      const updates: Record<string, unknown> = {
        event_status: status,
        resolved_at: new Date().toISOString()
      }
      if (resolved_by_user_id) updates.resolved_by = resolved_by_user_id
      if (notes !== undefined) updates.notes = notes

      const { error } = await supabase
        .from('help_requests')
        .update(updates)
        .eq('id', help_request_id)
      if (error) throw error
    }

    console.log('✅ Help request updated to', status)

    // --- Get caregivers for notifications ---

    const { data: caregivers, error: caregiversError } = await supabase
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
        if (caregiver.user_id === resolved_by_user_id) continue

        if (caregiver.apns_token && caregiver.push_notifications_enabled) {
          try {
            await sendExpoPushNotification(caregiver.apns_token, title, body, help_request_id, status)
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
