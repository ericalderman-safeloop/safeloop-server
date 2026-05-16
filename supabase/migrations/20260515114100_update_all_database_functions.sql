-- Update all database functions
-- Generated automatically from supabase/database_functions/*.sql

-- accept_caregiver_invitation function
-- accept_caregiver_invitation function
-- Accepts caregiver invitations and creates user accounts

CREATE OR REPLACE FUNCTION public.accept_caregiver_invitation(p_invitation_token text, p_email text, p_display_name text DEFAULT NULL::text, p_phone_number text DEFAULT NULL::text)
 RETURNS uuid
 LANGUAGE plpgsql
 SECURITY DEFINER
AS $function$
DECLARE
    invitation_record RECORD;
    new_user_id UUID;
BEGIN
    -- Get invitation details
    SELECT * INTO invitation_record
    FROM caregiver_invitations
    WHERE invitation_token = p_invitation_token
    AND email = p_email
    AND status = 'pending'
    AND expires_at > NOW();

    IF NOT FOUND THEN
        RAISE EXCEPTION 'Invalid or expired invitation token';
    END IF;

    -- Create caregiver user
    INSERT INTO users (
        auth_user_id,
        safeloop_account_id,
        email,
        display_name,
        phone_number,
        user_type
    )
    VALUES (
        auth.uid(),
        invitation_record.safeloop_account_id,
        p_email,
        p_display_name,
        p_phone_number,
        'caregiver'
    )
    RETURNING id INTO new_user_id;

    -- Create default notification preferences
    INSERT INTO notification_preferences (user_id) VALUES (new_user_id);

    -- Mark invitation as accepted
    UPDATE caregiver_invitations
    SET status = 'accepted',
        accepted_at = NOW()
    WHERE id = invitation_record.id;

    RETURN new_user_id;
END;
$function$;

-- Grant permissions
GRANT EXECUTE ON FUNCTION accept_caregiver_invitation TO service_role;
GRANT EXECUTE ON FUNCTION accept_caregiver_invitation TO anon;
-- add_wearer function
-- add_wearer function
-- Exported from Supabase database

 CREATE OR REPLACE FUNCTION public.add_wearer(p_name text, p_safeloop_account_id uuid DEFAULT NULL::uuid, p_date_of_birth date DEFAULT NULL::date, p_emergency_contact_name text DEFAULT NULL::text, p_emergency_contact_phone text DEFAULT NULL::text)
  RETURNS uuid
  LANGUAGE plpgsql
  SECURITY DEFINER
 AS $function$
 DECLARE
     wearer_id UUID;
     account_id UUID;
 BEGIN
     -- Use provided account ID or get from current user
     account_id := COALESCE(p_safeloop_account_id, get_user_safeloop_account_id());

     -- Create wearer
     INSERT INTO wearers (
         safeloop_account_id,
         name,
         date_of_birth,
         emergency_contact_name,
         emergency_contact_phone
     )
     VALUES (
         account_id,
         p_name,
         p_date_of_birth,
         p_emergency_contact_name,
         p_emergency_contact_phone
     )
     RETURNING id INTO wearer_id;

     -- Create default wearer settings
     INSERT INTO wearer_settings (wearer_id) VALUES (wearer_id);

     RETURN wearer_id;
 END;
 $function$
 ;

-- Grant permissions
GRANT EXECUTE ON FUNCTION add_wearer TO service_role;
GRANT EXECUTE ON FUNCTION add_wearer TO anon;

-- assign_caregiver_to_wearer function
-- assign_caregiver_to_wearer function
-- Exported from Supabase database

 CREATE OR REPLACE FUNCTION public.assign_caregiver_to_wearer(p_caregiver_user_id uuid, p_wearer_id uuid, p_relationship_type text DEFAULT 'family'::text, p_is_primary boolean DEFAULT false, p_is_emergency_contact boolean DEFAULT false)
  RETURNS uuid
  LANGUAGE plpgsql
  SECURITY DEFINER
 AS $function$
 DECLARE
     assignment_id UUID;
 BEGIN
     INSERT INTO caregiver_wearer_assignments (
         caregiver_user_id,
         wearer_id,
         relationship_type,
         is_primary,
         is_emergency_contact
     )
     VALUES (
         p_caregiver_user_id,
         p_wearer_id,
         p_relationship_type,
         p_is_primary,
         p_is_emergency_contact
     )
     ON CONFLICT (caregiver_user_id, wearer_id) DO UPDATE SET
         relationship_type = EXCLUDED.relationship_type,
         is_primary = EXCLUDED.is_primary,
         is_emergency_contact = EXCLUDED.is_emergency_contact
     RETURNING id INTO assignment_id;

     RETURN assignment_id;
 END;
 $function$
 ;

-- Grant permissions
GRANT EXECUTE ON FUNCTION assign_caregiver_to_wearer TO service_role;
GRANT EXECUTE ON FUNCTION assign_caregiver_to_wearer TO anon;

-- check_help_request_status function
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

-- create_caregiver_invitation_data function
-- create_caregiver_invitation_data function
-- Helper function for Edge Function - creates invitation data only (no external email)

CREATE OR REPLACE FUNCTION create_caregiver_invitation_data(
    p_email TEXT,
    p_safeloop_account_id UUID DEFAULT NULL
)
RETURNS TABLE(
    invitation_id UUID,
    invitation_token TEXT,
    invited_by_name TEXT,
    account_name TEXT
) LANGUAGE plpgsql SECURITY DEFINER AS $$
DECLARE
    account_id UUID;
    invitation_token TEXT;
    new_invitation_id UUID;
    inviter_name TEXT;
    safeloop_account_name TEXT;
BEGIN
    -- Use provided account ID or get from current user
    account_id := COALESCE(p_safeloop_account_id, get_user_safeloop_account_id());
    
    -- Generate unique invitation token
    invitation_token := encode(digest(p_email || account_id::TEXT || NOW()::TEXT, 'sha256'), 'hex');
    
    -- Get inviter name and account name for email
    SELECT u.display_name, sa.account_name
    INTO inviter_name, safeloop_account_name
    FROM users u
    JOIN safeloop_accounts sa ON sa.id = account_id
    WHERE u.auth_user_id = auth.uid();
    
    -- Create invitation
    INSERT INTO caregiver_invitations (
        safeloop_account_id,
        invited_by,
        email,
        invitation_token,
        expires_at
    )
    VALUES (
        account_id,
        (SELECT id FROM users WHERE auth_user_id = auth.uid()),
        p_email,
        invitation_token,
        NOW() + INTERVAL '7 days'
    )
    RETURNING id INTO new_invitation_id;
    
    -- Return invitation data for email
    RETURN QUERY
    SELECT 
        new_invitation_id,
        invitation_token,
        COALESCE(inviter_name, 'SafeLoop Admin') as invited_by_name,
        COALESCE(safeloop_account_name, 'SafeLoop Account') as account_name;
END;
$$;

-- Grant permissions
GRANT EXECUTE ON FUNCTION create_caregiver_invitation_data TO service_role;
GRANT EXECUTE ON FUNCTION create_caregiver_invitation_data TO anon;
-- create_help_request_data function
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
        p_location,
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
-- create_help_request function
-- create_help_request function
-- Creates help requests from watch devices and notifies caregivers

DROP FUNCTION IF EXISTS create_help_request(text, text, numeric, numeric, numeric, text);

CREATE OR REPLACE FUNCTION create_help_request(
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
    
    -- Insert the help request using the new schema structure
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
        p_location,
        NOW()
    )
    RETURNING * INTO new_request_record;
    
    -- Create notifications for assigned caregivers
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
    
    -- Return the help request data in the format the Edge Function expects
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
GRANT EXECUTE ON FUNCTION create_help_request TO service_role;
GRANT EXECUTE ON FUNCTION create_help_request TO anon;
-- create_safeloop_account function
-- create_safeloop_account function
-- Exported from Supabase database

 CREATE OR REPLACE FUNCTION public.create_safeloop_account(p_account_name text, p_admin_email text, p_admin_display_name text DEFAULT NULL::text, p_admin_phone text DEFAULT NULL::text)
  RETURNS uuid
  LANGUAGE plpgsql
  SECURITY DEFINER
 AS $function$
 DECLARE
     account_id UUID;
     admin_user_id UUID;
 BEGIN
     -- Create the SafeLoop account
     INSERT INTO safeloop_accounts (account_name, created_by)
     VALUES (p_account_name, auth.uid())
     RETURNING id INTO account_id;

     -- Create the Caregiver Admin user
     INSERT INTO users (auth_user_id, safeloop_account_id, email, display_name, phone_number, user_type)
     VALUES (auth.uid(), account_id, p_admin_email, p_admin_display_name, p_admin_phone, 'caregiver_admin')
     RETURNING id INTO admin_user_id;

     -- Update the account with the admin user ID
     UPDATE safeloop_accounts SET created_by = admin_user_id WHERE id = account_id;

     -- Create default notification preferences for admin
     INSERT INTO notification_preferences (user_id) VALUES (admin_user_id);

     RETURN account_id;
 END;
 $function$
 ;

-- Grant permissions
GRANT EXECUTE ON FUNCTION create_safeloop_account TO service_role;
GRANT EXECUTE ON FUNCTION create_safeloop_account TO anon;

-- create_user_on_signup function
-- create_user_on_signup function
-- Exported from Supabase database

 CREATE OR REPLACE FUNCTION public.create_user_on_signup(p_user_id uuid, p_email text, p_full_name text)
  RETURNS TABLE(user_id uuid, email text, full_name text, created_at timestamp with time zone)
  LANGUAGE plpgsql
  SECURITY DEFINER
 AS $function$
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
 $function$
 ;

-- Grant permissions
GRANT EXECUTE ON FUNCTION create_user_on_signup TO service_role;
GRANT EXECUTE ON FUNCTION create_user_on_signup TO anon;

-- delete_wearer_safely function
-- delete_wearer_safely function
-- Exported from Supabase database

 CREATE OR REPLACE FUNCTION public.delete_wearer_safely(p_wearer_id uuid)
  RETURNS boolean
  LANGUAGE plpgsql
  SECURITY DEFINER
 AS $function$
 DECLARE
     wearer_exists BOOLEAN := FALSE;
 BEGIN
     -- Check if wearer exists
     SELECT EXISTS(SELECT 1 FROM wearers WHERE id = p_wearer_id)
     INTO wearer_exists;

     IF NOT wearer_exists THEN
         RETURN FALSE;
     END IF;

     -- First, unassign any devices (set wearer_id to null)
     UPDATE devices
     SET wearer_id = NULL,
         updated_at = NOW()
     WHERE wearer_id = p_wearer_id;

     -- Delete any caregiver-wearer assignments
     DELETE FROM caregiver_wearer_assignments
     WHERE wearer_id = p_wearer_id;

     -- Delete any help requests for this wearer
     DELETE FROM help_requests
     WHERE wearer_id = p_wearer_id;

     -- Delete wearer settings
     DELETE FROM wearer_settings
     WHERE wearer_id = p_wearer_id;

     -- Finally, delete the wearer
     DELETE FROM wearers
     WHERE id = p_wearer_id;

     RETURN TRUE;
 END;
 $function$
 ;

-- Grant permissions
GRANT EXECUTE ON FUNCTION delete_wearer_safely TO service_role;
GRANT EXECUTE ON FUNCTION delete_wearer_safely TO anon;

-- get_account_by_wearer_id function
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
-- get_caregivers_for_help_request function
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
-- get_user_safeloop_account_id function
-- get_user_safeloop_account_id function
-- Exported from Supabase database

 CREATE OR REPLACE FUNCTION public.get_user_safeloop_account_id()
  RETURNS uuid
  LANGUAGE plpgsql
  SECURITY DEFINER
 AS $function$
 BEGIN
     RETURN (SELECT safeloop_account_id FROM users WHERE auth_user_id = auth.uid());
 END;
 $function$
 ;

-- Grant permissions
GRANT EXECUTE ON FUNCTION get_user_safeloop_account_id TO service_role;
GRANT EXECUTE ON FUNCTION get_user_safeloop_account_id TO anon;

-- invite_caregiver function
-- invite_caregiver function
-- Exported from Supabase database

 CREATE OR REPLACE FUNCTION public.invite_caregiver(p_email text, p_safeloop_account_id uuid DEFAULT NULL::uuid)
  RETURNS uuid
  LANGUAGE plpgsql
  SECURITY DEFINER
 AS $function$
 DECLARE
     invitation_id UUID;
     account_id UUID;
     invitation_token TEXT;
 BEGIN
     -- Use provided account ID or get from current user
     account_id := COALESCE(p_safeloop_account_id, get_user_safeloop_account_id());

     -- Generate unique invitation token
     invitation_token := encode(digest(p_email || account_id::TEXT || NOW()::TEXT, 'sha256'), 'hex');

     -- Create invitation
     INSERT INTO caregiver_invitations (
         safeloop_account_id,
         invited_by,
         email,
         invitation_token,
         expires_at
     )
     VALUES (
         account_id,
         (SELECT id FROM users WHERE auth_user_id = auth.uid()),
         p_email,
         invitation_token,
         NOW() + INTERVAL '7 days'
     )
     RETURNING id INTO invitation_id;

     RETURN invitation_id;
 END;
 $function$
 ;

-- Grant permissions
GRANT EXECUTE ON FUNCTION invite_caregiver TO service_role;
GRANT EXECUTE ON FUNCTION invite_caregiver TO anon;

-- is_caregiver_admin function
-- is_caregiver_admin function
-- Exported from Supabase database

 CREATE OR REPLACE FUNCTION public.is_caregiver_admin()
  RETURNS boolean
  LANGUAGE plpgsql
  SECURITY DEFINER
 AS $function$
 BEGIN
     RETURN EXISTS (
         SELECT 1 FROM users
         WHERE auth_user_id = auth.uid() AND user_type = 'caregiver_admin'
     );
 END;
 $function$
 ;

-- Grant permissions
GRANT EXECUTE ON FUNCTION is_caregiver_admin TO service_role;
GRANT EXECUTE ON FUNCTION is_caregiver_admin TO anon;

-- register_device function
-- register_device function
-- Exported from Supabase database

 CREATE OR REPLACE FUNCTION public.register_device(p_device_uuid text, p_seven_digit_code text)
  RETURNS uuid
  LANGUAGE plpgsql
  SECURITY DEFINER
 AS $function$
 DECLARE
     device_id UUID;
 BEGIN
     INSERT INTO devices (device_uuid, seven_digit_code)
     VALUES (p_device_uuid, p_seven_digit_code)
     ON CONFLICT (device_uuid) DO UPDATE SET
         seven_digit_code = EXCLUDED.seven_digit_code,
         updated_at = NOW()
     RETURNING id INTO device_id;

     RETURN device_id;
 END;
 $function$
 ;

-- Grant permissions
GRANT EXECUTE ON FUNCTION register_device TO service_role;
GRANT EXECUTE ON FUNCTION register_device TO anon;

-- update_updated_at_column function
-- update_updated_at_column function
-- Exported from Supabase database

 CREATE OR REPLACE FUNCTION public.update_updated_at_column()
  RETURNS trigger
  LANGUAGE plpgsql
 AS $function$
 BEGIN
     NEW.updated_at = NOW();
     RETURN NEW;
 END;
 $function$
 ;

-- Grant permissions
GRANT EXECUTE ON FUNCTION update_updated_at_column TO service_role;
GRANT EXECUTE ON FUNCTION update_updated_at_column TO anon;

-- verify_device function
-- verify_device function
-- Exported from Supabase database

 CREATE OR REPLACE FUNCTION public.verify_device(p_seven_digit_code text, p_wearer_id uuid)
  RETURNS boolean
  LANGUAGE plpgsql
  SECURITY DEFINER
 AS $function$
 DECLARE
     device_count INTEGER;
 BEGIN
     -- Check if the device exists and is unassigned
     SELECT COUNT(*) INTO device_count
     FROM devices
     WHERE seven_digit_code = p_seven_digit_code
     AND (wearer_id IS NULL OR is_verified = FALSE);

     IF device_count = 0 THEN
         RETURN FALSE;
     END IF;

     -- Assign the device to the wearer and mark as verified
     UPDATE devices
     SET wearer_id = p_wearer_id,
         is_verified = TRUE,
         updated_at = NOW()
     WHERE seven_digit_code = p_seven_digit_code;

     RETURN TRUE;
 END;
 $function$
 ;

-- Grant permissions
GRANT EXECUTE ON FUNCTION verify_device TO service_role;
GRANT EXECUTE ON FUNCTION verify_device TO anon;

