import { serve } from "https://deno.land/std@0.168.0/http/server.ts"
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2'

const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
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


serve(async (req) => {
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

    // Send SMS/Push notifications to caregivers
    if (caregivers && caregivers.length > 0) {
      console.log(`📱 Sending notifications to ${caregivers.length} caregivers`)

      for (const caregiver of caregivers) {
        try {
          const message = `🆘 ${event === 'fall' ? 'Fall detected' : 'Help requested'} for ${caregiver.wearer_name}${location ? ` at ${location}` : ''}. Please respond immediately.`

          // Send Expo push notification if user has token and notifications enabled
          if (caregiver.apns_token && caregiver.push_notifications_enabled) {
            await sendExpoPushNotification(caregiver.apns_token, caregiver.wearer_name, message, event, location)
          }

          // TODO: Send SMS via Twilio if configured
          if (caregiver.caregiver_phone) {
            console.log('📲 [SMS would be sent to]:', caregiver.caregiver_phone)
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
  location?: string
): Promise<void> {
  try {
    // Expo Push Notification API
    // Docs: https://docs.expo.dev/push-notifications/sending-notifications/
    const response = await fetch('https://exp.host/--/api/v2/push/send', {
      method: 'POST',
      headers: {
        'Accept': 'application/json',
        'Accept-Encoding': 'gzip, deflate',
        'Content-Type': 'application/json',
      },
      body: JSON.stringify({
        to: expoPushToken,
        sound: 'default',
        title: '🆘 SafeLoop Emergency Alert',
        body: message,
        data: {
          type: 'help_request',
          wearer_name: wearerName,
          event_type: eventType,
          location: location
        },
        priority: 'high',
        channelId: 'emergency', // Android notification channel
      })
    })

    const result = await response.json()

    if (result.data && result.data[0]?.status === 'ok') {
      console.log('✅ Expo push notification sent successfully')
    } else {
      console.error('❌ Failed to send Expo push notification:', result)
    }
  } catch (error) {
    console.error('❌ Error sending Expo push notification:', error)
  }
}