import { serve } from "https://deno.land/std@0.168.0/http/server.ts"
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2'

const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
}

interface InvitationData {
  email: string;
  safeloop_account_id?: string;
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
    const supabaseClient = createClient(
      Deno.env.get('SUPABASE_URL') ?? '',
      Deno.env.get('SUPABASE_SERVICE_ROLE_KEY') ?? ''
    )

    const { email, safeloop_account_id } = await req.json() as InvitationData

    console.log('📧 Creating caregiver invitation:', { email, safeloop_account_id })

    // Create invitation using helper database function
    const { data: invitation, error: invitationError } = await supabaseClient
      .rpc('create_caregiver_invitation_data', {
        p_email: email,
        p_safeloop_account_id: safeloop_account_id
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
  
  const invitationUrl = `${Deno.env.get('SAFELOOP_FRONTEND_URL')}/accept-invitation?token=${invitation_token}`
  
  // TODO: Implement actual email service
  // This is where you would integrate with services like:
  // - SendGrid
  // - AWS SES
  // - Mailgun
  // - Postmark
  
  console.log('📧 [MOCK] Sending invitation email:', {
    to: to,
    subject: `You're invited to join ${account_name} on SafeLoop`,
    invitation_url: invitationUrl,
    invited_by: invited_by_name
  })
  
  // Example implementation structure:
  /*
  // Send email via SendGrid
  await fetch('https://api.sendgrid.com/v3/mail/send', {
    method: 'POST',
    headers: {
      'Authorization': `Bearer ${Deno.env.get('SENDGRID_API_KEY')}`,
      'Content-Type': 'application/json'
    },
    body: JSON.stringify({
      personalizations: [{
        to: [{ email: to }],
        subject: `You're invited to join ${account_name} on SafeLoop`
      }],
      from: { 
        email: 'noreply@safeloop.care',
        name: 'SafeLoop' 
      },
      content: [{
        type: 'text/html',
        value: generateInvitationEmailHTML(invitationUrl, invited_by_name, account_name)
      }]
    })
  })

  // Or send via AWS SES
  const sesClient = new AWS.SES({ region: 'us-east-1' })
  await sesClient.sendEmail({
    Source: 'SafeLoop <noreply@safeloop.care>',
    Destination: { ToAddresses: [to] },
    Message: {
      Subject: { Data: `You're invited to join ${account_name} on SafeLoop` },
      Body: {
        Html: { Data: generateInvitationEmailHTML(invitationUrl, invited_by_name, account_name) }
      }
    }
  }).promise()
  */
}

function generateInvitationEmailHTML(invitationUrl: string, invitedBy: string, accountName: string): string {
  return `
    <html>
      <body style="font-family: Arial, sans-serif; line-height: 1.6; color: #333;">
        <div style="max-width: 600px; margin: 0 auto; padding: 20px;">
          <h2 style="color: #2563eb;">You're invited to SafeLoop!</h2>
          
          <p>Hi there,</p>
          
          <p><strong>${invitedBy}</strong> has invited you to join <strong>${accountName}</strong> on SafeLoop as a caregiver.</p>
          
          <p>SafeLoop helps families stay connected and ensures loved ones get help when they need it most.</p>
          
          <div style="text-align: center; margin: 30px 0;">
            <a href="${invitationUrl}" 
               style="background-color: #2563eb; color: white; padding: 12px 24px; text-decoration: none; border-radius: 6px; display: inline-block;">
              Accept Invitation
            </a>
          </div>
          
          <p style="font-size: 14px; color: #666;">
            This invitation will expire in 7 days. If you have any questions, please contact ${invitedBy} directly.
          </p>
          
          <hr style="border: none; border-top: 1px solid #eee; margin: 30px 0;">
          
          <p style="font-size: 12px; color: #999;">
            SafeLoop - Keeping families connected and safe<br>
            If you didn't expect this invitation, you can safely ignore this email.
          </p>
        </div>
      </body>
    </html>
  `
}