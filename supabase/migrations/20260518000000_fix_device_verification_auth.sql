-- H7: Remove auto-verification from get_account_by_wearer_id and revoke anon access.
-- Device verification is now an explicit step performed by the wearer-function Edge
-- Function (which runs as service_role), keeping the lookup read-only and anon-safe.

DROP FUNCTION IF EXISTS get_account_by_wearer_id(TEXT);

CREATE OR REPLACE FUNCTION get_account_by_wearer_id(p_wearer_id TEXT)
RETURNS TABLE(
    account_id UUID,
    account_name TEXT,
    wearer_id TEXT,
    wearer_name TEXT,
    status TEXT,
    is_verified BOOLEAN
) LANGUAGE plpgsql SECURITY DEFINER AS $$
BEGIN
    RETURN QUERY
    SELECT
        sa.id        AS account_id,
        sa.account_name,
        d.seven_digit_code AS wearer_id,
        w.name       AS wearer_name,
        'active'::text AS status,
        d.is_verified
    FROM safeloop_accounts sa
    JOIN wearers w ON w.safeloop_account_id = sa.id
    JOIN devices d ON d.wearer_id = w.id
    WHERE d.seven_digit_code = p_wearer_id;
END;
$$;

-- Only service_role may call this; wearer-function handles verification explicitly.
GRANT EXECUTE ON FUNCTION get_account_by_wearer_id TO service_role;
REVOKE EXECUTE ON FUNCTION get_account_by_wearer_id FROM anon;
REVOKE EXECUTE ON FUNCTION get_account_by_wearer_id FROM authenticated;
