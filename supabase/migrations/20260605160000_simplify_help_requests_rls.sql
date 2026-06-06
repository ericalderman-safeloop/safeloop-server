-- Supabase Realtime evaluates the SELECT RLS policy on every broadcast event.
-- Complex policies with UNION + JOIN subqueries appear to silently drop events
-- for non-admin caregivers, so a new help_request only shows up on the next
-- REST refetch (e.g. on screen focus). Admins didn't notice because their arm
-- of the UNION (is_caregiver_admin() = true) makes the whole expression
-- trivially satisfied.
--
-- Replace the subquery with a SECURITY DEFINER helper that does the same
-- logic in plpgsql. Realtime only sees a single function call.

CREATE OR REPLACE FUNCTION public.can_user_see_wearer(p_wearer_id uuid)
RETURNS boolean
LANGUAGE plpgsql
SECURITY DEFINER
STABLE
SET search_path = public
AS $$
DECLARE
    v_user_id uuid;
    v_account_id uuid;
    v_user_type text;
    v_wearer_account_id uuid;
BEGIN
    IF p_wearer_id IS NULL OR auth.uid() IS NULL THEN
        RETURN FALSE;
    END IF;

    SELECT id, safeloop_account_id, user_type
    INTO v_user_id, v_account_id, v_user_type
    FROM users
    WHERE auth_user_id = auth.uid();

    IF v_user_id IS NULL THEN
        RETURN FALSE;
    END IF;

    IF v_user_type = 'caregiver_admin' THEN
        SELECT safeloop_account_id INTO v_wearer_account_id
        FROM wearers
        WHERE id = p_wearer_id;
        RETURN v_wearer_account_id = v_account_id;
    END IF;

    RETURN EXISTS(
        SELECT 1
        FROM caregiver_wearer_assignments
        WHERE caregiver_user_id = v_user_id
          AND wearer_id = p_wearer_id
    );
END;
$$;

GRANT EXECUTE ON FUNCTION public.can_user_see_wearer(uuid) TO authenticated;
GRANT EXECUTE ON FUNCTION public.can_user_see_wearer(uuid) TO anon;
GRANT EXECUTE ON FUNCTION public.can_user_see_wearer(uuid) TO service_role;

DROP POLICY IF EXISTS "Users can view help requests for wearers they're assigned to" ON public.help_requests;
CREATE POLICY "Users can view help requests for wearers they're assigned to"
ON public.help_requests
FOR SELECT
TO public
USING (can_user_see_wearer(wearer_id));

DROP POLICY IF EXISTS "Caregivers can update help request status for their wearers" ON public.help_requests;
CREATE POLICY "Caregivers can update help request status for their wearers"
ON public.help_requests
FOR UPDATE
TO public
USING (can_user_see_wearer(wearer_id));
