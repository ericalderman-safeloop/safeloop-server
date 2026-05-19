import { serve } from "https://deno.land/std@0.168.0/http/server.ts"
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2'

const corsHeaders = {
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
}

interface InvitationData {
  email: string;
  safeloop_account_id?: string;
  wearer_ids?: string[];
}

interface EmailData {
  to: string;
  invitation_token: string;
  invited_by_name: string;
  account_name: string;
}

serve(async (req) => {
  // Handle CORS preflight requests
  if (req.method === 'OPTIONS') {
    return new Response('ok', { headers: corsHeaders })
  }

  try {
    // Use the caller's JWT so auth.uid() works in the DB function (populates invited_by)
    const authHeader = req.headers.get('Authorization')
    const userClient = createClient(
      Deno.env.get('SUPABASE_URL') ?? '',
      Deno.env.get('SUPABASE_ANON_KEY') ?? '',
      { global: { headers: { Authorization: authHeader ?? '' } } }
    )

    const { email, safeloop_account_id, wearer_ids } = await req.json() as InvitationData

    console.log('📧 Creating caregiver invitation:', { email, safeloop_account_id, wearer_ids })

    // Create invitation using helper database function
    const { data: invitation, error: invitationError } = await userClient
      .rpc('create_caregiver_invitation_data', {
        p_email: email,
        p_safeloop_account_id: safeloop_account_id,
        p_wearer_ids: wearer_ids ?? []
      })

    if (invitationError) {
      console.error('❌ Database error:', invitationError)
      throw invitationError
    }

    if (!invitation || invitation.length === 0) {
      throw new Error('Failed to create invitation')
    }

    const invitationRecord = invitation[0]
    console.log('✅ Invitation created:', invitationRecord.invitation_id)

    // Send email invitation
    try {
      await sendInvitationEmail({
        to: email,
        invitation_token: invitationRecord.invitation_token,
        invited_by_name: invitationRecord.invited_by_name,
        account_name: invitationRecord.account_name
      })
      
      console.log('📧 Invitation email sent successfully')
      
    } catch (emailError) {
      console.error('⚠️ Failed to send invitation email:', emailError)
      // Don't fail the entire request if email fails - invitation is still created
    }

    return new Response(
      JSON.stringify({
        success: true,
        invitation_id: invitationRecord.invitation_id,
        email_sent: true
      }),
      {
        headers: { ...corsHeaders, 'Content-Type': 'application/json' },
        status: 200,
      },
    )

  } catch (error) {
    console.error('❌ Invitation creation failed:', error)
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

async function sendInvitationEmail(data: EmailData): Promise<void> {
  const { to, invitation_token, invited_by_name, account_name } = data

  const apiKey = Deno.env.get('SENDGRID_API_KEY')

  if (!apiKey) {
    throw new Error('SendGrid API key not configured')
  }

  const deepLink = `safeloop-care://accept-invitation?token=${invitation_token}`

  const response = await fetch('https://api.sendgrid.com/v3/mail/send', {
    method: 'POST',
    headers: {
      'Authorization': `Bearer ${apiKey}`,
      'Content-Type': 'application/json',
    },
    body: JSON.stringify({
      from: { email: 'noreply@safeloop.care', name: 'SafeLoop' },
      personalizations: [{ to: [{ email: to }] }],
      subject: `You're invited to join ${account_name} on SafeLoop`,
      content: [{
        type: 'text/html',
        value: generateInvitationEmailHTML(deepLink, invited_by_name, account_name, to),
      }],
    })
  })

  if (!response.ok) {
    const errorBody = await response.text()
    console.error('❌ SendGrid error:', errorBody)
    throw new Error(`SendGrid send failed: ${response.status} ${errorBody}`)
  }

  console.log('✅ SendGrid invitation sent to', to)
}

function generateInvitationEmailHTML(deepLink: string, invitedBy: string, accountName: string, recipientEmail: string): string {
  return `
    <html>
      <body style="font-family: Arial, sans-serif; line-height: 1.6; color: #333; background-color: #f5f5f5;">
        <div style="max-width: 600px; margin: 0 auto; padding: 20px;">
          <div style="background: white; border-radius: 12px; padding: 40px; box-shadow: 0 2px 8px rgba(0,0,0,0.08);">

            <h2 style="color: #2196F3; margin-top: 0;">You're invited to SafeLoop</h2>

            <p>Hi there,</p>

            <p><strong>${invitedBy}</strong> has invited you to join <strong>${accountName}</strong> on SafeLoop as a caregiver.</p>

            <p>SafeLoop is a mobile app that keeps caregivers connected and ensures loved ones get help immediately when they need it.</p>

            <div style="background: #f0f7ff; border-radius: 8px; padding: 20px; margin: 24px 0;">
              <p style="margin: 0 0 8px 0; font-weight: bold; color: #1565C0;">To accept this invitation:</p>
              <ol style="margin: 0; padding-left: 20px; color: #333;">
                <li style="margin-bottom: 6px;">Download the <strong>SafeLoop Care</strong> app on your iPhone</li>
                <li style="margin-bottom: 6px;">Sign up using this email address: <strong>${recipientEmail}</strong></li>
                <li>Your invitation will be automatically applied</li>
              </ol>
            </div>

            <p style="font-size: 14px; color: #555;">
              If you already have the app installed, tap the button below to open it directly:
            </p>

            <div style="text-align: center; margin: 24px 0;">
              <a href="${deepLink}"
                 style="background-color: #2196F3; color: white; padding: 14px 32px; text-decoration: none; border-radius: 8px; display: inline-block; font-weight: bold; font-size: 16px;">
                Open in SafeLoop Care
              </a>
            </div>

            <p style="font-size: 13px; color: #888;">
              This invitation expires in 7 days. If you have questions, contact ${invitedBy} directly.
            </p>

            <hr style="border: none; border-top: 1px solid #eee; margin: 24px 0;">

            <p style="font-size: 12px; color: #aaa; margin: 0;">
              SafeLoop — Keeping families connected and safe<br>
              If you didn't expect this invitation, you can safely ignore this email.
            </p>

          </div>
        </div>
      </body>
    </html>
  `
}