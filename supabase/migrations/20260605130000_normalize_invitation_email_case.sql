-- Email addresses are case-insensitive in practice, but we previously stored
-- whatever the inviter typed and compared verbatim, which meant an admin who
-- typed "Eric@Work.com" created an invitation the invitee's lowercase SSO
-- session.email could never match. Normalize end-to-end.

-- 1. Backfill existing rows.
UPDATE public.caregiver_invitations
SET email = LOWER(email)
WHERE email <> LOWER(email);

-- 2. Always store and search by lowercase email in the invitation RPCs.
CREATE OR REPLACE FUNCTION create_caregiver_invitation_data(
    p_email TEXT,
    p_safeloop_account_id UUID DEFAULT NULL,
    p_wearer_ids UUID[] DEFAULT '{}',
    p_invited_user_type TEXT DEFAULT 'caregiver'
)
RETURNS TABLE(
    invitation_id UUID,
    invitation_token TEXT,
    invited_by_name TEXT,
    account_name TEXT
) LANGUAGE plpgsql SECURITY DEFINER AS $$
DECLARE
    account_id UUID;
    v_email TEXT;
    v_invitation_token TEXT;
    new_invitation_id UUID;
    inviter_name TEXT;
    safeloop_account_name TEXT;
BEGIN
    IF p_invited_user_type NOT IN ('caregiver', 'caregiver_admin') THEN
        RAISE EXCEPTION 'invited_user_type must be caregiver or caregiver_admin';
    END IF;

    v_email := LOWER(TRIM(p_email));
    account_id := COALESCE(p_safeloop_account_id, get_user_safeloop_account_id());

    v_invitation_token := encode(digest(v_email || account_id::TEXT || NOW()::TEXT, 'sha256'), 'hex');

    SELECT u.display_name, sa.account_name
    INTO inviter_name, safeloop_account_name
    FROM users u
    JOIN safeloop_accounts sa ON sa.id = account_id
    WHERE u.auth_user_id = auth.uid();

    INSERT INTO caregiver_invitations (
        safeloop_account_id,
        invited_by,
        email,
        invitation_token,
        expires_at,
        wearer_ids,
        invited_user_type
    )
    VALUES (
        account_id,
        (SELECT id FROM users WHERE auth_user_id = auth.uid()),
        v_email,
        v_invitation_token,
        NOW() + INTERVAL '7 days',
        COALESCE(p_wearer_ids, '{}'),
        p_invited_user_type
    )
    RETURNING id INTO new_invitation_id;

    RETURN QUERY
    SELECT
        new_invitation_id,
        v_invitation_token,
        COALESCE(inviter_name, 'SafeLoop Admin') as invited_by_name,
        COALESCE(safeloop_account_name, 'SafeLoop Account') as account_name;
END;
$$;

GRANT EXECUTE ON FUNCTION create_caregiver_invitation_data(TEXT, UUID, UUID[], TEXT) TO service_role;
GRANT EXECUTE ON FUNCTION create_caregiver_invitation_data(TEXT, UUID, UUID[], TEXT) TO anon;
GRANT EXECUTE ON FUNCTION create_caregiver_invitation_data(TEXT, UUID, UUID[], TEXT) TO authenticated;

-- 3. accept_caregiver_invitation also lowercases for both the lookup and the
--    users.email it stamps, so the user row matches the invitation row.
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
    wearer_id UUID;
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
        FOREACH wearer_id IN ARRAY invitation_record.wearer_ids LOOP
            INSERT INTO caregiver_wearer_assignments (
                caregiver_user_id,
                wearer_id,
                relationship_type,
                is_primary,
                is_emergency_contact
            )
            VALUES (
                new_user_id,
                wearer_id,
                'caregiver',
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
