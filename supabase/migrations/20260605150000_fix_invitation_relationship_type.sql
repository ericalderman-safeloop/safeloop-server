-- accept_caregiver_invitation inserted relationship_type = 'caregiver', but the
-- caregiver_wearer_assignments_relationship_type_check constraint only allows
-- family/spouse/child/parent/sibling/friend/primary_caregiver/backup_caregiver/
-- medical_professional/service_provider/emergency_contact. The RPC failed on
-- the first invitee who had wearer_ids attached. Switch to 'family' to match
-- the default used by assign_caregiver_to_wearer.

CREATE OR REPLACE FUNCTION public.accept_caregiver_invitation(
    p_invitation_token text,
    p_email text,
    p_display_name text DEFAULT NULL,
    p_phone_number text DEFAULT NULL
)
RETURNS uuid
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    invitation_record RECORD;
    v_email TEXT;
    new_user_id UUID;
    v_wearer_id UUID;
BEGIN
    v_email := LOWER(TRIM(p_email));

    SELECT * INTO invitation_record
    FROM caregiver_invitations
    WHERE invitation_token = p_invitation_token
    AND email = v_email
    AND status = 'pending'
    AND expires_at > NOW();

    IF NOT FOUND THEN
        RAISE EXCEPTION 'Invalid or expired invitation token';
    END IF;

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
        v_email,
        p_display_name,
        p_phone_number,
        COALESCE(invitation_record.invited_user_type, 'caregiver')
    )
    RETURNING id INTO new_user_id;

    INSERT INTO notification_preferences (user_id) VALUES (new_user_id);

    IF invitation_record.wearer_ids IS NOT NULL THEN
        FOREACH v_wearer_id IN ARRAY invitation_record.wearer_ids LOOP
            INSERT INTO caregiver_wearer_assignments (
                caregiver_user_id,
                wearer_id,
                relationship_type,
                is_primary,
                is_emergency_contact
            )
            VALUES (
                new_user_id,
                v_wearer_id,
                'family',
                false,
                false
            )
            ON CONFLICT DO NOTHING;
        END LOOP;
    END IF;

    UPDATE caregiver_invitations
    SET status = 'accepted',
        accepted_at = NOW()
    WHERE id = invitation_record.id;

    RETURN new_user_id;
END;
$$;

GRANT EXECUTE ON FUNCTION accept_caregiver_invitation TO service_role;
GRANT EXECUTE ON FUNCTION accept_caregiver_invitation TO anon;
GRANT EXECUTE ON FUNCTION accept_caregiver_invitation TO authenticated;
