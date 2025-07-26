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