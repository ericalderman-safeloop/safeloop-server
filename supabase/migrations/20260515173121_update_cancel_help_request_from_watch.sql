-- Update cancel_help_request_from_watch function
-- Generated automatically from supabase/database_functions/cancel_help_request_from_watch.sql

CREATE OR REPLACE FUNCTION cancel_help_request_from_watch(
    p_help_request_id UUID,
    p_wearer_device_id TEXT
)
RETURNS BOOLEAN
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    actual_wearer_id UUID;
    rows_updated INTEGER;
BEGIN
    -- Verify the help request belongs to this wearer's device
    SELECT w.id INTO actual_wearer_id
    FROM wearers w
    JOIN devices d ON d.wearer_id = w.id
    WHERE d.seven_digit_code = p_wearer_device_id
    AND d.is_verified = TRUE;

    IF actual_wearer_id IS NULL THEN
        RETURN FALSE;
    END IF;

    UPDATE help_requests
    SET
        event_status = 'false_alarm',
        resolved_at = NOW(),
        notes = COALESCE(notes || E'\n', '') ||
                'Cancelled by wearer from watch at ' ||
                TO_CHAR(NOW() AT TIME ZONE 'UTC', 'Mon DD, YYYY HH12:MI AM') || ' UTC'
    WHERE id = p_help_request_id
      AND wearer_id = actual_wearer_id
      AND event_status IN ('active', 'responded_to');

    GET DIAGNOSTICS rows_updated = ROW_COUNT;
    RETURN rows_updated > 0;
END;
$$;

GRANT EXECUTE ON FUNCTION cancel_help_request_from_watch TO anon;
GRANT EXECUTE ON FUNCTION cancel_help_request_from_watch TO service_role;
