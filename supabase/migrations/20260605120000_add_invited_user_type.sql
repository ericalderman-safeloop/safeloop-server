-- Multi-admin support: track the role a caregiver was invited as, and add a
-- helper RPC for promoting/demoting an existing caregiver.

-- 1. Track the role on the invitation itself so accept_caregiver_invitation
--    can stamp the right user_type when the invitee signs up.
ALTER TABLE public.caregiver_invitations
  ADD COLUMN IF NOT EXISTS invited_user_type TEXT NOT NULL DEFAULT 'caregiver'
  CHECK (invited_user_type IN ('caregiver', 'caregiver_admin'));

-- 2. Extend create_caregiver_invitation_data to accept invited_user_type.
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
    v_invitation_token TEXT;
    new_invitation_id UUID;
    inviter_name TEXT;
    safeloop_account_name TEXT;
BEGIN
    IF p_invited_user_type NOT IN ('caregiver', 'caregiver_admin') THEN
        RAISE EXCEPTION 'invited_user_type must be caregiver or caregiver_admin';
    END IF;

    account_id := COALESCE(p_safeloop_account_id, get_user_safeloop_account_id());

    v_invitation_token := encode(digest(p_email || account_id::TEXT || NOW()::TEXT, 'sha256'), 'hex');

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
        p_email,
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

-- Drop the previous 3-arg overload so the signature is unambiguous.
DROP FUNCTION IF EXISTS create_caregiver_invitation_data(TEXT, UUID, UUID[]);

GRANT EXECUTE ON FUNCTION create_caregiver_invitation_data(TEXT, UUID, UUID[], TEXT) TO service_role;
GRANT EXECUTE ON FUNCTION create_caregiver_invitation_data(TEXT, UUID, UUID[], TEXT) TO anon;
GRANT EXECUTE ON FUNCTION create_caregiver_invitation_data(TEXT, UUID, UUID[], TEXT) TO authenticated;

-- 3. accept_caregiver_invitation now honors the invitation's invited_user_type.
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
    new_user_id UUID;
    wearer_id UUID;
BEGIN
    SELECT * INTO invitation_record
    FROM caregiver_invitations
    WHERE invitation_token = p_invitation_token
    AND email = p_email
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
        p_email,
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

-- 4. update_caregiver_role: admin-only promote/demote of an existing caregiver
--    in the same SafeLoop account. SECURITY DEFINER so RLS on users doesn't
--    need a new policy; we enforce admin + same-account inside the function.
CREATE OR REPLACE FUNCTION public.update_caregiver_role(
    p_target_user_id UUID,
    p_new_user_type TEXT
)
RETURNS VOID
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    caller_account_id UUID;
    target_account_id UUID;
    remaining_admin_count INT;
BEGIN
    IF p_new_user_type NOT IN ('caregiver', 'caregiver_admin') THEN
        RAISE EXCEPTION 'user_type must be caregiver or caregiver_admin';
    END IF;

    IF NOT is_caregiver_admin() THEN
        RAISE EXCEPTION 'Only account admins can change caregiver roles';
    END IF;

    SELECT safeloop_account_id INTO caller_account_id
    FROM users WHERE auth_user_id = auth.uid();

    SELECT safeloop_account_id INTO target_account_id
    FROM users WHERE id = p_target_user_id;

    IF target_account_id IS NULL THEN
        RAISE EXCEPTION 'Target user not found';
    END IF;

    IF caller_account_id IS NULL OR caller_account_id <> target_account_id THEN
        RAISE EXCEPTION 'Cannot change role of a user outside your account';
    END IF;

    -- Prevent demoting the last admin so the account is never left admin-less.
    IF p_new_user_type = 'caregiver' THEN
        SELECT COUNT(*) INTO remaining_admin_count
        FROM users
        WHERE safeloop_account_id = caller_account_id
          AND user_type = 'caregiver_admin'
          AND id <> p_target_user_id;

        IF remaining_admin_count = 0 THEN
            RAISE EXCEPTION 'Cannot demote the last admin on this account';
        END IF;
    END IF;

    UPDATE users
    SET user_type = p_new_user_type,
        updated_at = NOW()
    WHERE id = p_target_user_id;
END;
$$;

GRANT EXECUTE ON FUNCTION update_caregiver_role(UUID, TEXT) TO service_role;
GRANT EXECUTE ON FUNCTION update_caregiver_role(UUID, TEXT) TO authenticated;
