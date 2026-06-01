import { createClient } from 'https://esm.sh/@supabase/supabase-js@2'

const corsHeaders = {
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
}

interface RefineLocationPayload {
  help_request_id: string
  wearer_device_id: string
  latitude: number
  longitude: number
  accuracy: number
}

Deno.serve(async (req) => {
  if (req.method === 'OPTIONS') {
    return new Response('ok', { headers: corsHeaders })
  }

  try {
    const serviceClient = createClient(
      Deno.env.get('SUPABASE_URL') ?? '',
      Deno.env.get('SUPABASE_SERVICE_ROLE_KEY') ?? ''
    )

    const { help_request_id, wearer_device_id, latitude, longitude, accuracy } =
      await req.json() as RefineLocationPayload

    // Verify this help request belongs to this wearer and is still active
    const { data: helpRequest, error: fetchError } = await serviceClient
      .from('help_requests')
      .select('id, event_status, wearer_id')
      .eq('id', help_request_id)
      .single()

    if (fetchError || !helpRequest) {
      return new Response(JSON.stringify({ success: false, error: 'Help request not found' }), {
        headers: { ...corsHeaders, 'Content-Type': 'application/json' }, status: 404
      })
    }

    if (helpRequest.event_status === 'resolved' || helpRequest.event_status === 'false_alarm') {
      return new Response(JSON.stringify({ success: false, error: 'Help request already resolved' }), {
        headers: { ...corsHeaders, 'Content-Type': 'application/json' }, status: 400
      })
    }

    // Verify wearer ownership via device ID
    const { data: wearer, error: wearerError } = await serviceClient
      .from('wearers')
      .select('id')
      .eq('device_id', wearer_device_id)
      .single()

    if (wearerError || !wearer || wearer.id !== helpRequest.wearer_id) {
      return new Response(JSON.stringify({ success: false, error: 'Unauthorized' }), {
        headers: { ...corsHeaders, 'Content-Type': 'application/json' }, status: 401
      })
    }

    const { error: updateError } = await serviceClient
      .from('help_requests')
      .update({
        location_latitude: latitude,
        location_longitude: longitude,
        location_accuracy: accuracy,
      })
      .eq('id', help_request_id)

    if (updateError) throw updateError

    console.log(`📍 Location refined for ${help_request_id}: ${accuracy}m accuracy`)

    return new Response(
      JSON.stringify({ success: true }),
      { headers: { ...corsHeaders, 'Content-Type': 'application/json' }, status: 200 }
    )

  } catch (error) {
    console.error('❌ refine-location failed:', error)
    return new Response(
      JSON.stringify({ success: false, error: error.message }),
      { headers: { ...corsHeaders, 'Content-Type': 'application/json' }, status: 400 }
    )
  }
})
