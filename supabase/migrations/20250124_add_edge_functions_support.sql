-- Add support functions for Edge Functions

-- Function to get account information by wearer_id
CREATE OR REPLACE FUNCTION get_account_by_wearer_id(p_wearer_id TEXT)
RETURNS TABLE(
    account_id UUID,
    account_name TEXT,
    wearer_id TEXT,
    wearer_name TEXT,
    status TEXT
) LANGUAGE plpgsql SECURITY DEFINER AS $$
BEGIN
    RETURN QUERY
    SELECT 
        sa.id as account_id,
        sa.account_name,
        w.wearer_id,
        w.full_name as wearer_name,
        w.status
    FROM safeloop_accounts sa
    JOIN wearers w ON w.account_id = sa.id
    WHERE w.wearer_id = p_wearer_id;
END;
$$;

-- Function to create user record on signup (for auth webhooks)
CREATE OR REPLACE FUNCTION create_user_on_signup(
    p_user_id UUID,
    p_email TEXT,
    p_full_name TEXT
)
RETURNS TABLE(
    user_id UUID,
    email TEXT,
    full_name TEXT,
    created_at TIMESTAMPTZ
) LANGUAGE plpgsql SECURITY DEFINER AS $$
DECLARE
    new_user_record RECORD;
BEGIN
    -- Insert user record if it doesn't exist
    INSERT INTO users (id, email, full_name, created_at, updated_at)
    VALUES (p_user_id, p_email, p_full_name, NOW(), NOW())
    ON CONFLICT (id) DO UPDATE SET
        email = EXCLUDED.email,
        full_name = EXCLUDED.full_name,
        updated_at = NOW()
    RETURNING * INTO new_user_record;
    
    -- Return the user data
    RETURN QUERY
    SELECT 
        new_user_record.id,
        new_user_record.email,
        new_user_record.full_name,
        new_user_record.created_at;
END;
$$;

-- Grant execute permissions to the service role (for Edge Functions)
GRANT EXECUTE ON FUNCTION get_account_by_wearer_id TO service_role;
GRANT EXECUTE ON FUNCTION create_user_on_signup TO service_role;