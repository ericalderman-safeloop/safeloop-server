-- Update create_caregiver_invitation_data function
-- Generated automatically from supabase/database_functions/create_caregiver_invitation_data.sql

-- create_caregiver_invitation_data function
-- Helper function for Edge Function - creates invitation data only (no external email)

CREATE OR REPLACE FUNCTION create_caregiver_invitation_data(
    p_email TEXT,
    p_safeloop_account_id UUID DEFAULT NULL
)
RETURNS TABLE(
    invitation_id UUID,
    invitation_token TEXT,
    invited_by_name TEXT,
    account_name TEXT
) LANGUAGE plpgsql SECURITY DEFINER AS $$
DECLARE
    account_id UUID;
    invitation_token TEXT;
    new_invitation_id UUID;
    inviter_name TEXT;
    safeloop_account_name TEXT;
BEGIN
    -- Use provided account ID or get from current user
    account_id := COALESCE(p_safeloop_account_id, get_user_safeloop_account_id());
    
    -- Generate unique invitation token
    invitation_token := encode(digest(p_email || account_id::TEXT || NOW()::TEXT, 'sha256'), 'hex');
    
    -- Get inviter name and account name for email
    SELECT u.display_name, sa.name
    INTO inviter_name, safeloop_account_name
    FROM users u
    JOIN safeloop_accounts sa ON sa.id = account_id
    WHERE u.auth_user_id = auth.uid();
    
    -- Create invitation
    INSERT INTO caregiver_invitations (
        safeloop_account_id,
        invited_by,
        email,
        invitation_token,
        expires_at
    )
    VALUES (
        account_id,
        (SELECT id FROM users WHERE auth_user_id = auth.uid()),
        p_email,
        invitation_token,
        NOW() + INTERVAL '7 days'
    )
    RETURNING id INTO new_invitation_id;
    
    -- Return invitation data for email
    RETURN QUERY
    SELECT 
        new_invitation_id,
        invitation_token,
        COALESCE(inviter_name, 'SafeLoop Admin') as invited_by_name,
        COALESCE(safeloop_account_name, 'SafeLoop Account') as account_name;
END;
$$;

-- Grant permissions
GRANT EXECUTE ON FUNCTION create_caregiver_invitation_data TO service_role;
GRANT EXECUTE ON FUNCTION create_caregiver_invitation_data TO anon;