-- Force replace the broken get_account_by_wearer_id function with correct schema references
-- The wearer_id parameter is actually the seven_digit_code from devices table

DROP FUNCTION IF EXISTS get_account_by_wearer_id(TEXT);

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
        d.seven_digit_code as wearer_id,
        w.name as wearer_name,
        CASE 
            WHEN d.is_verified THEN 'active'::text
            ELSE 'inactive'::text
        END as status
    FROM safeloop_accounts sa
    JOIN wearers w ON w.safeloop_account_id = sa.id
    JOIN devices d ON d.wearer_id = w.id
    WHERE d.seven_digit_code = p_wearer_id
    AND d.is_verified = TRUE;
END;
$$;

-- Ensure the function has proper permissions
GRANT EXECUTE ON FUNCTION get_account_by_wearer_id TO service_role;
GRANT EXECUTE ON FUNCTION get_account_by_wearer_id TO anon;