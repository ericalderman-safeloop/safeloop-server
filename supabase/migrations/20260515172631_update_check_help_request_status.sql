-- Update check_help_request_status function
-- Generated automatically from supabase/database_functions/check_help_request_status.sql

DROP FUNCTION IF EXISTS check_help_request_status(UUID);

CREATE OR REPLACE FUNCTION check_help_request_status(
    p_help_request_id UUID
)
RETURNS TABLE(event_status TEXT, responder_name TEXT)
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
BEGIN
    RETURN QUERY
    SELECT hr.event_status, u.display_name
    FROM help_requests hr
    LEFT JOIN users u ON u.id = hr.responded_by
    WHERE hr.id = p_help_request_id;
END;
$$;
