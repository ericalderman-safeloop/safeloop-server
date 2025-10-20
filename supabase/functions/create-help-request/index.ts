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

  const supabaseClient = createClient(
    Deno.env.get('SUPABASE_URL') ?? '',
    Deno.env.get('SUPABASE_SERVICE_ROLE_KEY') ?? ''
  )

  // Get user's push tokens
  const { data: user, error: userError } = await supabaseClient
    .from('users')
    .select('apns_token, fcm_token, phone_number, push_notifications_enabled')
    .eq('id', recipient_user_id)
    .single()

  if (userError || !user) {
    console.error('❌ Could not fetch user for notifications:', userError)
    return
  }

  const message = `🆘 ${event_type === 'fall' ? 'Fall detected' : 'Help requested'} for ${wearer_name}${location ? ` at ${location}` : ''}. Please respond immediately.`

  // Send iOS push notification if user has APNs token
  if (user.apns_token && user.push_notifications_enabled) {
    await sendAPNsNotification(user.apns_token, wearer_name, message, event_type)
  }

  // Send Android push notification if user has FCM token
  if (user.fcm_token && user.push_notifications_enabled) {
    await sendFCMNotification(user.fcm_token, wearer_name, message, event_type)
  }

  // TODO: Send SMS via Twilio if configured
  if (user.phone_number) {
    console.log('📲 [SMS would be sent to]:', user.phone_number)
  }
}

async function sendAPNsNotification(
  deviceToken: string,
  wearerName: string,
  message: string,
  eventType: string
): Promise<void> {
  try {
    const fcmServerKey = Deno.env.get('FCM_SERVER_KEY')

    if (!fcmServerKey) {
      console.log('⚠️ FCM_SERVER_KEY not configured, skipping iOS push notification')
      return
    }

    // Use FCM's HTTP v1 API which supports both iOS and Android
    // Note: You'll need to configure this in Firebase Console and get the service account key
    const response = await fetch(
      `https://fcm.googleapis.com/v1/projects/${Deno.env.get('FIREBASE_PROJECT_ID')}/messages:send`,
      {
        method: 'POST',
        headers: {
          'Authorization': `Bearer ${fcmServerKey}`,
          'Content-Type': 'application/json'
        },
        body: JSON.stringify({
          message: {
            token: deviceToken,
            notification: {
              title: '🆘 SafeLoop Emergency Alert',
              body: message
            },
            apns: {
              headers: {
                'apns-priority': '10', // Immediate delivery
                'apns-push-type': 'alert'
              },
              payload: {
                aps: {
                  alert: {
                    title: '🆘 SafeLoop Emergency Alert',
                    body: message
                  },
                  sound: 'default',
                  badge: 1,
                  'interruption-level': 'critical', // iOS 15+ critical alerts
                  'content-available': 1
                }
              }
            },
            data: {
              type: 'help_request',
              wearer_name: wearerName,
              event_type: eventType
            }
          }
        })
      }
    )

    if (response.ok) {
      console.log('✅ iOS push notification sent successfully')
    } else {
      const error = await response.text()
      console.error('❌ Failed to send iOS push notification:', error)
    }
  } catch (error) {
    console.error('❌ Error sending iOS push notification:', error)
  }
}

async function sendFCMNotification(
  deviceToken: string,
  wearerName: string,
  message: string,
  eventType: string
): Promise<void> {
  try {
    const fcmServerKey = Deno.env.get('FCM_SERVER_KEY')

    if (!fcmServerKey) {
      console.log('⚠️ FCM_SERVER_KEY not configured, skipping Android push notification')
      return
    }

    const response = await fetch(
      `https://fcm.googleapis.com/v1/projects/${Deno.env.get('FIREBASE_PROJECT_ID')}/messages:send`,
      {
        method: 'POST',
        headers: {
          'Authorization': `Bearer ${fcmServerKey}`,
          'Content-Type': 'application/json'
        },
        body: JSON.stringify({
          message: {
            token: deviceToken,
            notification: {
              title: '🆘 SafeLoop Emergency Alert',
              body: message
            },
            android: {
              priority: 'high',
              notification: {
                sound: 'default',
                priority: 'max',
                channel_id: 'emergency_alerts'
              }
            },
            data: {
              type: 'help_request',
              wearer_name: wearerName,
              event_type: eventType
            }
          }
        })
      }
    )

    if (response.ok) {
      console.log('✅ Android push notification sent successfully')
    } else {
      const error = await response.text()
      console.error('❌ Failed to send Android push notification:', error)
    }
  } catch (error) {
    console.error('❌ Error sending Android push notification:', error)
  }
}