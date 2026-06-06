-- The existing SELECT policy on caregiver_invitations only allows reading rows
-- whose safeloop_account_id is in the caller's users.safeloop_account_id — but
-- the invitee has no users row yet (that's literally what the invitation is
-- for). The lookup silently returned null and the invitee fell through to the
-- "create new account, become admin" path.
--
-- Allow an authenticated user to view invitations addressed to their own auth
-- email. This is the only case where invitee == auth.jwt() email, so it's safe.

CREATE POLICY "Invitees can view their own invitations"
ON public.caregiver_invitations
FOR SELECT
TO authenticated
USING (
  LOWER(email) = LOWER(auth.jwt() ->> 'email')
);
