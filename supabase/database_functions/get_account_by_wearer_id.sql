-- get_account_by_wearer_id function
-- Validates watch device and returns account information
-- Also automatically verifies unverified devices on first call

DROP FUNCTION IF EXISTS get_account_by_wearer_id(TEXT);

CREATE OR REPLACE FUNCTION get_account_by_wearer_id(p_wearer_id TEXT)
RETURNS TABLE(
    account_id UUID,
    account_name TEXT,
    wearer_id TEXT,
    wearer_name TEXT,
    status TEXT,
    was_verified BOOLEAN
) LANGUAGE plpgsql SECURITY DEFINER AS $$
DECLARE
    device_exists BOOLEAN := FALSE;
    was_already_verified BOOLEAN := FALSE;
BEGIN
    -- Check if device exists and get its current verification status
    SELECT EXISTS(SELECT 1 FROM devices WHERE seven_digit_code = p_wearer_id), 
           COALESCE((SELECT is_verified FROM devices WHERE seven_digit_code = p_wearer_id), FALSE)
    INTO device_exists, was_already_verified;
    
    -- If device doesn't exist at all, return empty
    IF NOT device_exists THEN
        RETURN;
    END IF;
    
    -- If device exists but isn't verified yet, verify it now
    IF NOT was_already_verified THEN
        UPDATE devices 
        SET is_verified = TRUE,
            updated_at = NOW()
        WHERE seven_digit_code = p_wearer_id;
    END IF;
    
    -- Now return the account information
    RETURN QUERY
    SELECT 
        sa.id as account_id,
        sa.account_name,
        d.seven_digit_code as wearer_id,
        w.name as wearer_name,
        'active'::text as status,
        was_already_verified as was_verified
    FROM safeloop_accounts sa
    JOIN wearers w ON w.safeloop_account_id = sa.id
    JOIN devices d ON d.wearer_id = w.id
    WHERE d.seven_digit_code = p_wearer_id;
END;
$$;

-- Grant permissions
GRANT EXECUTE ON FUNCTION get_account_by_wearer_id TO service_role;
GRANT EXECUTE ON FUNCTION get_account_by_wearer_id TO anon;