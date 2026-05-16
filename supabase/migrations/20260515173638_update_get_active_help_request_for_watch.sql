-- Update get_active_help_request_for_watch function
-- Generated automatically from supabase/database_functions/get_active_help_request_for_watch.sql

CREATE OR REPLACE FUNCTION get_active_help_request_for_watch(
    p_wearer_device_id TEXT
)
RETURNS TABLE(
    help_request_id UUID,
    event_status TEXT,
    responder_name TEXT
)
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    actual_wearer_id UUID;
BEGIN
    SELECT w.id INTO actual_wearer_id
    FROM wearers w
    JOIN devices d ON d.wearer_id = w.id
    WHERE d.seven_digit_code = p_wearer_device_id
    AND d.is_verified = TRUE;

    IF actual_wearer_id IS NULL THEN
        RETURN;
    END IF;

    RETURN QUERY
    SELECT hr.id, hr.event_status, u.display_name
    FROM help_requests hr
    LEFT JOIN users u ON u.id = hr.responded_by
    WHERE hr.wearer_id = actual_wearer_id
      AND hr.event_status IN ('active', 'responded_to')
    ORDER BY hr.created_at DESC
    LIMIT 1;
END;
$$;

GRANT EXECUTE ON FUNCTION get_active_help_request_for_watch TO anon;
GRANT EXECUTE ON FUNCTION get_active_help_request_for_watch TO service_role;
