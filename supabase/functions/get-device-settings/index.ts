import { createClient } from 'https://esm.sh/@supabase/supabase-js@2'

const corsHeaders = {
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
}

Deno.serve(async (req) => {
  if (req.method === 'OPTIONS') {
    return new Response('ok', { headers: corsHeaders })
  }

  try {
    const supabaseClient = createClient(
      Deno.env.get('SUPABASE_URL') ?? '',
      Deno.env.get('SUPABASE_SERVICE_ROLE_KEY') ?? ''
    )

    const { wearer_device_id } = await req.json()

    if (!wearer_device_id) {
      return new Response(
        JSON.stringify({ fall_detection_mode: 'apple' }),
        { headers: { ...corsHeaders, 'Content-Type': 'application/json' }, status: 200 }
      )
    }

    const { data: device, error: deviceError } = await supabaseClient
      .from('devices')
      .select('wearer_id')
      .eq('seven_digit_code', wearer_device_id)
      .single()

    if (deviceError || !device?.wearer_id) {
      return new Response(
        JSON.stringify({ fall_detection_mode: 'apple' }),
        { headers: { ...corsHeaders, 'Content-Type': 'application/json' }, status: 200 }
      )
    }

    const { data: wearer, error: wearerError } = await supabaseClient
      .from('wearers')
      .select('fall_detection_mode')
      .eq('id', device.wearer_id)
      .single()

    if (wearerError || !wearer) {
      return new Response(
        JSON.stringify({ fall_detection_mode: 'apple' }),
        { headers: { ...corsHeaders, 'Content-Type': 'application/json' }, status: 200 }
      )
    }

    return new Response(
      JSON.stringify({ fall_detection_mode: wearer.fall_detection_mode ?? 'apple' }),
      { headers: { ...corsHeaders, 'Content-Type': 'application/json' }, status: 200 }
    )
  } catch (error) {
    console.error('get-device-settings error:', error)
    return new Response(
      JSON.stringify({ fall_detection_mode: 'apple' }),
      { headers: { ...corsHeaders, 'Content-Type': 'application/json' }, status: 200 }
    )
  }
})
