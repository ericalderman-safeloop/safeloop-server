// Setup type definitions for built-in Supabase Runtime APIs
import "jsr:@supabase/functions-js/edge-runtime.d.ts"
import { createClient } from "@supabase/supabase-js"

const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
}

interface HelpRequest {
  type: string
  wearer_id: string
  event: string
  resolution: string | null
  location: string
}

interface ValidateWatchRequest {
  type: string
  wearer_id: string
}

Deno.serve(async (req) => {
  // Handle CORS preflight requests
  if (req.method === 'OPTIONS') {
    return new Response('ok', { headers: corsHeaders })
  }

  try {
    // Initialize Supabase client
    const supabaseClient = createClient(
      Deno.env.get('SUPABASE_URL') ?? '',
      Deno.env.get('SUPABASE_SERVICE_ROLE_KEY') ?? ''
    )

    const data = await req.json()
    console.log('>>>>>>>>>>>>> Wearer Functions: ' + data.type + ' <<<<<<<<<<<<<<<<<<<<')

    switch (data.type) {
      case "validate_watch": {
        const request = data as ValidateWatchRequest
        
        // Find account by seven_digit_code directly from the schema
        const { data: accountData, error: accountError } = await supabaseClient
          .from('devices')
          .select(`
            seven_digit_code,
            wearer_id,
            wearers!inner(
              name,
              safeloop_account_id,
              safeloop_accounts!inner(
                id,
                account_name
              )
            )
          `)
          .eq('seven_digit_code', request.wearer_id)
          .eq('is_verified', true)
          .single()

        if (accountError) {
          console.error('Error finding account:', accountError)
          return new Response(
            JSON.stringify({ success: false, message: 'Error finding account' }), 
            { 
              status: 500,
              headers: { ...corsHeaders, 'Content-Type': 'application/json' }
            }
          )
        }

        if (!accountData) {
          console.log('No account found for wearer_id: ' + request.wearer_id)
          return new Response(
            JSON.stringify({ success: false, message: 'No account found for the provided wearer_id' }), 
            { 
              status: 200,
              headers: { ...corsHeaders, 'Content-Type': 'application/json' }
            }
          )
        }

        const account = {
          account_id: accountData.wearers.safeloop_accounts.id,
          account_name: accountData.wearers.safeloop_accounts.account_name,
          wearer_id: accountData.seven_digit_code,
          wearer_name: accountData.wearers.name,
          status: 'active'
        }
        console.log('Account found: ', account)
        return new Response(
          JSON.stringify({ success: true, message: 'Account found', account: account }), 
          { 
            status: 200,
            headers: { ...corsHeaders, 'Content-Type': 'application/json' }
          }
        )
      }

      case "help_request": {
        const request = data as HelpRequest
        
        try {
          // Create help request using the database function
          const { data: helpRequestData, error: helpRequestError } = await supabaseClient
            .rpc('create_help_request', {
              p_wearer_id: request.wearer_id,
              p_event: request.event as 'fall' | 'manual_request',
              p_resolution: request.resolution as 'confirmed' | 'unresponsive' | null,
              p_location: request.location
            })

          if (helpRequestError) {
            console.error('Error creating help request:', helpRequestError)
            return new Response(
              JSON.stringify({ success: false, message: 'Error saving help request' }), 
              { 
                status: 500,
                headers: { ...corsHeaders, 'Content-Type': 'application/json' }
              }
            )
          }

          console.log('Help request saved successfully:', helpRequestData)
          return new Response(
            JSON.stringify({ success: true, message: 'Help request saved successfully', data: helpRequestData }), 
            { 
              status: 200,
              headers: { ...corsHeaders, 'Content-Type': 'application/json' }
            }
          )
        } catch (error) {
          console.error('Error saving help request:', error)
          return new Response(
            JSON.stringify({ success: false, message: 'Error saving help request' }), 
            { 
              status: 500,
              headers: { ...corsHeaders, 'Content-Type': 'application/json' }
            }
          )
        }
      }

      default:
        return new Response(
          JSON.stringify({ success: false, message: 'Invalid request type' }), 
          { 
            status: 400,
            headers: { ...corsHeaders, 'Content-Type': 'application/json' }
          }
        )
    }
  } catch (error) {
    console.error('Function error:', error)
    return new Response(
      JSON.stringify({ success: false, message: 'Internal server error' }), 
      { 
        status: 500,
        headers: { ...corsHeaders, 'Content-Type': 'application/json' }
      }
    )
  }
})