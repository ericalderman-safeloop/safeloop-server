-- invite_caregiver function
-- Exported from Supabase database

 CREATE OR REPLACE FUNCTION public.invite_caregiver(p_email text, p_safeloop_account_id uuid DEFAULT NULL::uuid)+
  RETURNS uuid                                                                                                  +
  LANGUAGE plpgsql                                                                                              +
  SECURITY DEFINER                                                                                              +
 AS $function$                                                                                                  +
 DECLARE                                                                                                        +
     invitation_id UUID;                                                                                        +
     account_id UUID;                                                                                           +
     invitation_token TEXT;                                                                                     +
 BEGIN                                                                                                          +
     -- Use provided account ID or get from current user                                                        +
     account_id := COALESCE(p_safeloop_account_id, get_user_safeloop_account_id());                             +
                                                                                                                +
     -- Generate unique invitation token                                                                        +
     invitation_token := encode(digest(p_email || account_id::TEXT || NOW()::TEXT, 'sha256'), 'hex');           +
                                                                                                                +
     -- Create invitation                                                                                       +
     INSERT INTO caregiver_invitations (                                                                        +
         safeloop_account_id,                                                                                   +
         invited_by,                                                                                            +
         email,                                                                                                 +
         invitation_token,                                                                                      +
         expires_at                                                                                             +
     )                                                                                                          +
     VALUES (                                                                                                   +
         account_id,                                                                                            +
         (SELECT id FROM users WHERE auth_user_id = auth.uid()),                                                +
         p_email,                                                                                               +
         invitation_token,                                                                                      +
         NOW() + INTERVAL '7 days'                                                                              +
     )                                                                                                          +
     RETURNING id INTO invitation_id;                                                                           +
                                                                                                                +
     RETURN invitation_id;                                                                                      +
 END;                                                                                                           +
 $function$                                                                                                     +
 ;

-- Grant permissions
GRANT EXECUTE ON FUNCTION invite_caregiver TO service_role;
GRANT EXECUTE ON FUNCTION invite_caregiver TO anon;
