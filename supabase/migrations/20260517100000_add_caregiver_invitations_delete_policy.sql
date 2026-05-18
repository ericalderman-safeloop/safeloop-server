-- Allow account admins to delete (cancel) pending invitations
CREATE POLICY "Caregiver admins can delete invitations"
ON public.caregiver_invitations
FOR DELETE
TO authenticated
USING (
  safeloop_account_id IN (
    SELECT safeloop_account_id FROM public.users
    WHERE auth_user_id = auth.uid()
  )
);
