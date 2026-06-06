import { createClient } from 'https://esm.sh/@supabase/supabase-js@2'

const corsHeaders = {
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
}

interface HelpRequestData {
  wearer_id: string;
  event: string;
  resolution?: string;
  location?: string;
  location_lat?: number;
  location_lng?: number;
}


Deno.serve(async (req) => {
  // Handle CORS preflight requests
  if (req.method === 'OPTIONS') {
    return new Response('ok', { headers: corsHeaders })
  }

  try {
    const supabaseClient = createClient(
      Deno.env.get('SUPABASE_URL') ?? '',
      Deno.env.get('SUPABASE_SERVICE_ROLE_KEY') ?? ''
    )

    const { wearer_id, event, resolution, location, location_lat, location_lng } = await req.json() as HelpRequestData

    console.log('🆘 Creating help request:', { wearer_id, event, location })

    // Create help request using helper database function
    const { data: helpRequest, error: helpRequestError } = await supabaseClient
      .rpc('create_help_request_data', {
        p_wearer_id: wearer_id,
        p_event: event,
        p_resolution: resolution,
        p_location: location,
        p_location_lat: location_lat,
        p_location_lng: location_lng
      })

    if (helpRequestError) {
      console.error('❌ Database error:', helpRequestError)
      throw helpRequestError
    }

    if (!helpRequest || helpRequest.length === 0) {
      throw new Error('Failed to create help request')
    }

    const request = helpRequest[0]
    console.log('✅ Help request created:', request.id)

    // Get caregivers for notifications
    const { data: caregivers, error: caregiversError } = await supabaseClient
      .rpc('get_caregivers_for_help_request', {
        p_help_request_id: request.id
      })

    if (caregiversError) {
      console.error('⚠️ Error getting caregivers:', caregiversError)
    }

    // Send push notifications to caregivers
    if (caregivers && caregivers.length > 0) {
      console.log(`📱 Sending notifications to ${caregivers.length} caregivers`)

      for (const caregiver of caregivers) {
        try {
          const message = `🆘 ${event === 'fall' ? 'Fall detected' : 'Help requested'} for ${caregiver.wearer_name}${location ? ` at ${location}` : ''}. Please respond immediately.`

          // Send to all unique tokens the caregiver has registered (iOS + Android)
          if (caregiver.push_notifications_enabled) {
            const tokens = [...new Set([caregiver.apns_token, caregiver.fcm_token].filter(Boolean))]
            // Per-caregiver sound preference. 'alarm' → bundled siren .caf (loud,
            // attention-grabbing). 'standard' → system default. Anything
            // unexpected falls back to the alarm because this is safety-critical.
            const sound = caregiver.help_request_sound === 'standard' ? 'default' : 'safeloop_alarm.caf'
            for (const token of tokens) {
              await sendExpoPushNotification(token, caregiver.wearer_name, message, event, request.id, location, supabaseClient, caregiver.user_id, sound)
            }
          }


        } catch (notificationError) {
          console.error('⚠️ Failed to send notification to caregiver:', caregiver.user_id, notificationError)
          // Continue with other caregivers even if one fails
        }
      }
    }

    return new Response(
      JSON.stringify({
        success: true,
        help_request: request,
        notifications_sent: caregivers?.length || 0
      }),
      {
        headers: { ...corsHeaders, 'Content-Type': 'application/json' },
        status: 200,
      },
    )

  } catch (error) {
    console.error('❌ Help request creation failed:', error)
    return new Response(
      JSON.stringify({
        success: false,
        error: error.message
      }),
      {
        headers: { ...corsHeaders, 'Content-Type': 'application/json' },
        status: 400,
      },
    )
  }
})

async function sendExpoPushNotification(
  expoPushToken: string,
  wearerName: string,
  message: string,
  eventType: string,
  helpRequestId: string,
  location?: string,
  supabaseClient?: ReturnType<typeof createClient>,
  userId?: string,
  sound: string = 'default'
): Promise<void> {
  try {
    const response = await fetch('https://exp.host/--/api/v2/push/send', {
      method: 'POST',
      headers: {
        'Accept': 'application/json',
        'Accept-Encoding': 'gzip, deflate',
        'Content-Type': 'application/json',
      },
      body: JSON.stringify({
        to: expoPushToken,
        sound,
        title: '🆘 SafeLoop Emergency Alert',
        body: message,
        data: {
          type: 'help_request',
          help_request_id: helpRequestId,
          wearer_name: wearerName,
          event_type: eventType,
          location: location
        },
        priority: 'high',
        channelId: 'emergency',
      })
    })

    const result = await response.json()
    const ticket = result.data?.[0]

    if (ticket?.status === 'ok') {
      console.log('✅ Expo push notification sent successfully')
    } else if (ticket?.details?.error === 'DeviceNotRegistered' && supabaseClient && userId) {
      // Token is no longer valid — clear it so future sends don't waste requests
      console.log('⚠️ DeviceNotRegistered — clearing push token for user:', userId)
      await supabaseClient.from('users').update({ apns_token: null, fcm_token: null }).eq('id', userId)
    } else {
      console.error('❌ Failed to send Expo push notification:', result)
    }
  } catch (error) {
    console.error('❌ Error sending Expo push notification:', error)
  }
}