-- M9: Drop duplicate create_help_request function.
-- create_help_request_data is used by the create-help-request Edge Function.
-- create_help_request was used by the legacy wearer-function help_request path
-- which has been removed. Both functions were identical; keep only the _data variant.
DROP FUNCTION IF EXISTS create_help_request(TEXT, TEXT, TEXT, TEXT, NUMERIC, NUMERIC);

-- M10: Fix create_user_on_signup to populate auth_user_id (not just id).
-- Previously only id was set, leaving auth_user_id NULL so lookups using
-- WHERE auth_user_id = auth.uid() could not find newly signed-up users.
CREATE OR REPLACE FUNCTION public.create_user_on_signup(
    p_user_id UUID,
    p_email TEXT,
    p_full_name TEXT
)
RETURNS TABLE(user_id UUID, email TEXT, full_name TEXT, created_at TIMESTAMPTZ)
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    new_user_record RECORD;
BEGIN
    INSERT INTO users (id, auth_user_id, email, full_name, created_at, updated_at)
    VALUES (p_user_id, p_user_id, p_email, p_full_name, NOW(), NOW())
    ON CONFLICT (id) DO UPDATE SET
        auth_user_id = COALESCE(users.auth_user_id, EXCLUDED.auth_user_id),
        email        = EXCLUDED.email,
        full_name    = EXCLUDED.full_name,
        updated_at   = NOW()
    RETURNING * INTO new_user_record;

    RETURN QUERY
    SELECT
        new_user_record.id,
        new_user_record.email,
        new_user_record.full_name,
        new_user_record.created_at;
END;
$$;

-- M11: Remove explicit help_requests deletion from delete_wearer_safely.
-- help_requests.wearer_id has ON DELETE CASCADE, so deleting the wearer
-- already cascades to help_requests. The explicit DELETE was redundant and
-- ran before the wearer was deleted, making it impossible to ever preserve
-- history by changing the cascade behavior later.
CREATE OR REPLACE FUNCTION public.delete_wearer_safely(p_wearer_id UUID)
RETURNS BOOLEAN
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    wearer_exists BOOLEAN := FALSE;
BEGIN
    SELECT EXISTS(SELECT 1 FROM wearers WHERE id = p_wearer_id)
    INTO wearer_exists;

    IF NOT wearer_exists THEN
        RETURN FALSE;
    END IF;

    -- Unassign devices (SET NULL per FK definition)
    UPDATE devices
    SET wearer_id  = NULL,
        updated_at = NOW()
    WHERE wearer_id = p_wearer_id;

    -- Remove caregiver assignments
    DELETE FROM caregiver_wearer_assignments WHERE wearer_id = p_wearer_id;

    -- Remove wearer settings
    DELETE FROM wearer_settings WHERE wearer_id = p_wearer_id;

    -- Delete wearer — help_requests cascade automatically via FK
    DELETE FROM wearers WHERE id = p_wearer_id;

    RETURN TRUE;
END;
$$;

-- M12: Remove emergency_contact_* parameters from add_wearer.
-- Those columns were dropped from the wearers table; calling the old
-- signature would throw a column-not-found error.
DROP FUNCTION IF EXISTS public.add_wearer(TEXT, UUID, DATE, TEXT, TEXT);

CREATE OR REPLACE FUNCTION public.add_wearer(
    p_name TEXT,
    p_safeloop_account_id UUID DEFAULT NULL,
    p_date_of_birth DATE DEFAULT NULL
)
RETURNS TABLE(wearer_id UUID, name TEXT, safeloop_account_id UUID)
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    new_wearer RECORD;
    account_id UUID;
BEGIN
    account_id := COALESCE(p_safeloop_account_id, get_user_safeloop_account_id());

    INSERT INTO wearers (name, safeloop_account_id, date_of_birth, created_at, updated_at)
    VALUES (p_name, account_id, p_date_of_birth, NOW(), NOW())
    RETURNING * INTO new_wearer;

    RETURN QUERY
    SELECT new_wearer.id, new_wearer.name, new_wearer.safeloop_account_id;
END;
$$;

GRANT EXECUTE ON FUNCTION public.add_wearer TO service_role;
GRANT EXECUTE ON FUNCTION public.add_wearer TO authenticated;

-- M13: Use cryptographically random bytes for invitation tokens.
-- SHA-256(email || account_id || NOW()) is predictable; replace with
-- gen_random_bytes(32) encoded as hex.
CREATE OR REPLACE FUNCTION create_caregiver_invitation_data(
    p_email TEXT,
    p_safeloop_account_id UUID DEFAULT NULL,
    p_wearer_ids UUID[] DEFAULT '{}'
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
    wearer_uuid UUID;
BEGIN
    account_id := COALESCE(p_safeloop_account_id, get_user_safeloop_account_id());

    -- Cryptographically random token (256 bits)
    invitation_token := encode(gen_random_bytes(32), 'hex');

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

    -- Assign wearers to invitation if provided
    IF p_wearer_ids IS NOT NULL AND array_length(p_wearer_ids, 1) > 0 THEN
        FOREACH wearer_uuid IN ARRAY p_wearer_ids LOOP
            INSERT INTO invitation_wearer_assignments (invitation_id, wearer_id)
            VALUES (new_invitation_id, wearer_uuid)
            ON CONFLICT DO NOTHING;
        END LOOP;
    END IF;

    RETURN QUERY
    SELECT
        new_invitation_id,
        invitation_token,
        COALESCE(inviter_name, 'SafeLoop Admin') AS invited_by_name,
        COALESCE(safeloop_account_name, 'SafeLoop Account') AS account_name;
END;
$$;

GRANT EXECUTE ON FUNCTION create_caregiver_invitation_data TO service_role;
GRANT EXECUTE ON FUNCTION create_caregiver_invitation_data TO authenticated;
