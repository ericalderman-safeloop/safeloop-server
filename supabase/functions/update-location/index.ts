import { serve } from "https://deno.land/std@0.168.0/http/server.ts"
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2'

const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
}

interface LocationUpdate {
  wearer_id: string; // Seven-digit device code
  help_request_id?: string; // Optional - can lookup active request if not provided
  latitude: number;
  longitude: number;
  accuracy?: number;
  altitude?: number;
  speed?: number;
  heading?: number;
  timestamp?: string;
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

    const {
      wearer_id,
      help_request_id,
      latitude,
      longitude,
      accuracy,
      altitude,
      speed,
      heading,
      timestamp
    } = await req.json() as LocationUpdate

    console.log('📍 Receiving location update:', { wearer_id, latitude, longitude })

    // Find the actual wearer UUID from the seven_digit_code
    const { data: wearerData, error: wearerError } = await supabaseClient
      .from('wearers')
      .select('id')
      .eq('id', (
        await supabaseClient
          .from('devices')
          .select('wearer_id')
          .eq('seven_digit_code', wearer_id)
          .eq('is_verified', true)
          .single()
      ).data?.wearer_id || '')
      .single()

    if (wearerError || !wearerData) {
      console.error('❌ Wearer not found:', wearer_id)
      throw new Error('Invalid wearer_id')
    }

    const actual_wearer_id = wearerData.id

    // Find the active help request for this wearer (if not provided)
    let activeHelpRequestId = help_request_id

    if (!activeHelpRequestId) {
      const { data: activeRequest, error: requestError } = await supabaseClient
        .from('help_requests')
        .select('id')
        .eq('wearer_id', actual_wearer_id)
        .eq('event_status', 'active')
        .order('created_at', { ascending: false })
        .limit(1)
        .single()

      if (requestError || !activeRequest) {
        console.log('⚠️ No active help request found for wearer:', wearer_id)
        return new Response(
          JSON.stringify({
            success: false,
            message: 'No active help request found'
          }),
          {
            headers: { ...corsHeaders, 'Content-Type': 'application/json' },
            status: 200,
          },
        )
      }

      activeHelpRequestId = activeRequest.id
    }

    // Insert the location update
    const { data: locationUpdate, error: insertError } = await supabaseClient
      .from('location_updates')
      .insert({
        help_request_id: activeHelpRequestId,
        wearer_id: actual_wearer_id,
        latitude,
        longitude,
        accuracy,
        altitude,
        speed,
        heading,
        timestamp: timestamp || new Date().toISOString()
      })
      .select()
      .single()

    if (insertError) {
      console.error('❌ Failed to insert location update:', insertError)
      throw insertError
    }

    console.log('✅ Location update stored:', locationUpdate.id)

    return new Response(
      JSON.stringify({
        success: true,
        location_update_id: locationUpdate.id
      }),
      {
        headers: { ...corsHeaders, 'Content-Type': 'application/json' },
        status: 200,
      },
    )

  } catch (error) {
    console.error('❌ Location update failed:', error)
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
