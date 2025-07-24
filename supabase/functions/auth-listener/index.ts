// Setup type definitions for built-in Supabase Runtime APIs
import "jsr:@supabase/functions-js/edge-runtime.d.ts"
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2'

interface AuthEventPayload {
  type: string
  table: string
  record: {
    id: string
    email?: string
    raw_user_meta_data?: {
      full_name?: string
      name?: string
    }
    created_at: string
  }
  old_record?: any
}

Deno.serve(async (req) => {
  try {
    // Initialize Supabase client
    const supabaseClient = createClient(
      Deno.env.get('SUPABASE_URL') ?? '',
      Deno.env.get('SUPABASE_SERVICE_ROLE_KEY') ?? ''
    )

    const payload: AuthEventPayload = await req.json()
    console.log('Auth event received:', payload.type)

    // Handle user creation events
    if (payload.type === 'INSERT' && payload.table === 'users') {
      const user = payload.record
      
      // Extract display name from user metadata
      const displayName = user.raw_user_meta_data?.full_name || 
                          user.raw_user_meta_data?.name || 
                          null

      // Create user record using database function
      const { data: userData, error: userError } = await supabaseClient
        .rpc('create_user_on_signup', {
          p_user_id: user.id,
          p_email: user.email || null,
          p_full_name: displayName
        })

      if (userError) {
        console.error('Error creating user:', userError)
        return new Response(
          JSON.stringify({ success: false, message: 'Error creating user' }), 
          { 
            status: 500,
            headers: { 'Content-Type': 'application/json' }
          }
        )
      }

      console.log('User created successfully:', userData)
      return new Response(
        JSON.stringify({ success: true, message: 'User created successfully', data: userData }), 
        { 
          status: 200,
          headers: { 'Content-Type': 'application/json' }
        }
      )
    }

    // Return success for other events (no action needed)
    return new Response(
      JSON.stringify({ success: true, message: 'Event processed' }), 
      { 
        status: 200,
        headers: { 'Content-Type': 'application/json' }
      }
    )

  } catch (error) {
    console.error('Auth listener error:', error)
    return new Response(
      JSON.stringify({ success: false, message: 'Internal server error' }), 
      { 
        status: 500,
        headers: { 'Content-Type': 'application/json' }
      }
    )
  }
})