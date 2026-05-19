-- M18: Tighten invitation INSERT policy to require caregiver_admin role.
-- The original policy allowed any account member to create invitations.
-- Only admins should be able to invite new caregivers.
DROP POLICY IF EXISTS "Caregiver admins can create invitations" ON public.caregiver_invitations;

CREATE POLICY "Caregiver admins can create invitations"
ON public.caregiver_invitations
FOR INSERT
TO authenticated
WITH CHECK (
  safeloop_account_id IN (
    SELECT safeloop_account_id FROM public.users
    WHERE auth_user_id = auth.uid()
      AND user_type = 'caregiver_admin'
  )
);
