-- Update get_caregivers_for_help_request function
-- Generated automatically from supabase/database_functions/get_caregivers_for_help_request.sql

-- get_caregivers_for_help_request function
-- Helper function to get caregiver contact info for notifications

-- Drop the old function first since we're changing return type
DROP FUNCTION IF EXISTS get_caregivers_for_help_request(UUID);

CREATE OR REPLACE FUNCTION get_caregivers_for_help_request(
    p_help_request_id UUID
)
RETURNS TABLE(
    user_id UUID,
    wearer_name TEXT,
    caregiver_email TEXT,
    caregiver_phone TEXT,
    apns_token TEXT,
    fcm_token TEXT,
    push_notifications_enabled BOOLEAN
) LANGUAGE plpgsql SECURITY DEFINER AS $$
BEGIN
    RETURN QUERY
    SELECT
        u.id as user_id,
        w.name as wearer_name,
        u.email as caregiver_email,
        u.phone_number as caregiver_phone,
        u.apns_token as apns_token,
        u.fcm_token as fcm_token,
        u.push_notifications_enabled as push_notifications_enabled
    FROM help_requests hr
    JOIN wearers w ON w.id = hr.wearer_id
    JOIN caregiver_wearer_assignments cwa ON cwa.wearer_id = w.id
    JOIN users u ON u.id = cwa.caregiver_user_id
    WHERE hr.id = p_help_request_id;
END;
$$;

-- Grant permissions
GRANT EXECUTE ON FUNCTION get_caregivers_for_help_request TO service_role;
GRANT EXECUTE ON FUNCTION get_caregivers_for_help_request TO anon;