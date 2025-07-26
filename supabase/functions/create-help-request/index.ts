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

interface NotificationData {
  recipient_user_id: string;
  wearer_name: string;
  event_type: string;
  location?: string;
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
          await sendNotifications({
            recipient_user_id: caregiver.user_id,
            wearer_name: caregiver.wearer_name,
            event_type: event,
            location: location
          })
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

async function sendNotifications(data: NotificationData): Promise<void> {
  const { recipient_user_id, wearer_name, event_type, location } = data
  
  // TODO: Implement actual SMS/Push notification services
  // This is where you would integrate with services like:
  // - Twilio for SMS
  // - Firebase Cloud Messaging for push notifications
  // - Apple Push Notification Service for iOS
  
  console.log('📲 [MOCK] Sending SMS/Push notification:', {
    to: recipient_user_id,
    message: `🆘 ${event_type === 'fall' ? 'Fall detected' : 'Help requested'} for ${wearer_name}${location ? ` at ${location}` : ''}. Please respond immediately.`,
    priority: 'critical'
  })
  
  // Example implementation structure:
  /*
  // Send SMS via Twilio
  await fetch('https://api.twilio.com/2010-04-01/Accounts/{AccountSid}/Messages.json', {
    method: 'POST',
    headers: {
      'Authorization': `Basic ${btoa(`${twilioSid}:${twilioToken}`)}`,
      'Content-Type': 'application/x-www-form-urlencoded'
    },
    body: new URLSearchParams({
      To: caregiver.phone_number,
      From: twilioPhoneNumber,
      Body: message
    })
  })

  // Send Push Notification via FCM
  await fetch('https://fcm.googleapis.com/fcm/send', {
    method: 'POST',
    headers: {
      'Authorization': `key=${fcmServerKey}`,
      'Content-Type': 'application/json'
    },
    body: JSON.stringify({
      to: caregiver.fcm_token,
      notification: {
        title: '🆘 Emergency Alert',
        body: message,
        priority: 'high'
      }
    })
  })
  */
}