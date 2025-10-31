-- Update create_help_request_data function
-- Generated automatically from supabase/database_functions/create_help_request_data.sql

-- create_help_request_data function
-- Helper function for Edge Function - creates help request data only (no external notifications)

CREATE OR REPLACE FUNCTION create_help_request_data(
    p_wearer_id TEXT,
    p_event TEXT,
    p_resolution TEXT DEFAULT NULL,
    p_location TEXT DEFAULT NULL,
    p_location_lat NUMERIC DEFAULT NULL,
    p_location_lng NUMERIC DEFAULT NULL
)
RETURNS TABLE(
    id UUID,
    wearer_id UUID,
    event TEXT,
    resolution TEXT,
    location TEXT,
    created_at TIMESTAMPTZ
) LANGUAGE plpgsql SECURITY DEFINER AS $$
DECLARE
    actual_wearer_id UUID;
    new_request_record RECORD;
BEGIN
    -- Find the actual wearer UUID from the seven_digit_code
    SELECT w.id INTO actual_wearer_id
    FROM wearers w
    JOIN devices d ON d.wearer_id = w.id
    WHERE d.seven_digit_code = p_wearer_id
    AND d.is_verified = TRUE;
    
    IF actual_wearer_id IS NULL THEN
        RAISE EXCEPTION 'Invalid wearer_id: %', p_wearer_id;
    END IF;
    
    -- Insert the help request using the schema structure
    INSERT INTO help_requests (
        wearer_id, 
        request_type, 
        fall_response, 
        location_latitude, 
        location_longitude,
        notes,
        created_at
    )
    VALUES (
        actual_wearer_id,
        p_event,
        p_resolution,
        p_location_lat,
        p_location_lng,
        NULL,
        NOW()
    )
    RETURNING * INTO new_request_record;
    
    -- Create notifications for assigned caregivers (for internal app notifications)
    INSERT INTO notifications (recipient_user_id, wearer_id, help_request_id, notification_type, title, message, priority)
    SELECT 
        cwa.caregiver_user_id,
        actual_wearer_id,
        new_request_record.id,
        CASE 
            WHEN p_event = 'fall' THEN 'fall_detected'
            ELSE 'manual_help_request'
        END,
        CASE 
            WHEN p_event = 'fall' THEN 'Fall Detected'
            ELSE 'Help Requested'
        END,
        CASE 
            WHEN p_event = 'fall' THEN 'A fall has been detected. Please respond immediately.'
            ELSE 'Help has been requested. Please respond immediately.'
        END,
        'critical'
    FROM caregiver_wearer_assignments cwa
    WHERE cwa.wearer_id = actual_wearer_id;
    
    -- Return the help request data
    RETURN QUERY
    SELECT 
        new_request_record.id,
        new_request_record.wearer_id,
        new_request_record.request_type as event,
        new_request_record.fall_response as resolution,
        new_request_record.notes as location,
        new_request_record.created_at;
END;
$$;

-- Grant permissions
GRANT EXECUTE ON FUNCTION create_help_request_data TO service_role;
GRANT EXECUTE ON FUNCTION create_help_request_data TO anon;