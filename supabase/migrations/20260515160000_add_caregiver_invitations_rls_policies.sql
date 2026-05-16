-- Add RLS policies for caregiver_invitations table
-- Previously missing: no SELECT/INSERT/UPDATE policies existed despite RLS being enabled

-- Allow account admins/members to view invitations for their account
CREATE POLICY "Users can view invitations for their account"
ON public.caregiver_invitations
FOR SELECT
TO authenticated
USING (
  safeloop_account_id IN (
    SELECT safeloop_account_id FROM public.users
    WHERE auth_user_id = auth.uid()
  )
);

-- Allow authenticated users to insert invitations for their own account
CREATE POLICY "Caregiver admins can create invitations"
ON public.caregiver_invitations
FOR INSERT
TO authenticated
WITH CHECK (
  safeloop_account_id IN (
    SELECT safeloop_account_id FROM public.users
    WHERE auth_user_id = auth.uid()
  )
);

-- Allow invited user (by email) or account members to update (e.g. accept/cancel)
CREATE POLICY "Users can update invitations for their account or their email"
ON public.caregiver_invitations
FOR UPDATE
TO authenticated
USING (
  safeloop_account_id IN (
    SELECT safeloop_account_id FROM public.users
    WHERE auth_user_id = auth.uid()
  )
  OR
  email IN (
    SELECT email FROM public.users
    WHERE auth_user_id = auth.uid()
  )
);
