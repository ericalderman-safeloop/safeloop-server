CREATE OR REPLACE FUNCTION check_help_request_status(
    p_help_request_id UUID
)
RETURNS TABLE(event_status TEXT)
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
BEGIN
    RETURN QUERY
    SELECT hr.event_status
    FROM help_requests hr
    WHERE hr.id = p_help_request_id;
END;
$$;
