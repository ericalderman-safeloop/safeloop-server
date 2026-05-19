import { createClient } from 'https://esm.sh/@supabase/supabase-js@2'

const corsHeaders = {
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
}

Deno.serve(async (req) => {
  if (req.method === 'OPTIONS') {
    return new Response('ok', { headers: corsHeaders })
  }

  try {
    const { wearer_device_id } = await req.json()

    const supabase = createClient(
      Deno.env.get('SUPABASE_URL')!,
      Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!
    )

    // Try wearer-specific setting first
    if (wearer_device_id) {
      const { data: specific } = await supabase
        .from('fall_detection_settings')
        .select('sensitivity')
        .eq('wearer_device_id', wearer_device_id)
        .maybeSingle()

      if (specific) {
        return new Response(JSON.stringify({ sensitivity: specific.sensitivity }), {
          headers: { ...corsHeaders, 'Content-Type': 'application/json' }
        })
      }
    }

    // Fall back to global default
    const { data: global } = await supabase
      .from('fall_detection_settings')
      .select('sensitivity')
      .eq('wearer_device_id', 'GLOBAL')
      .maybeSingle()

    return new Response(JSON.stringify({ sensitivity: global?.sensitivity ?? 'medium' }), {
      headers: { ...corsHeaders, 'Content-Type': 'application/json' }
    })

  } catch (error) {
    console.error('❌ get-fall-detection-settings error:', error)
    return new Response(JSON.stringify({ error: error.message }), {
      status: 500, headers: { ...corsHeaders, 'Content-Type': 'application/json' }
    })
  }
})
