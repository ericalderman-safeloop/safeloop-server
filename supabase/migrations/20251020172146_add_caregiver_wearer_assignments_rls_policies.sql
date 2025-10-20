-- Enable RLS policies for caregiver_wearer_assignments table
-- This allows authenticated users to view and manage assignments for their account

-- Allow authenticated users to SELECT assignments for wearers in their account
CREATE POLICY "Users can view assignments for wearers in their account"
  ON caregiver_wearer_assignments
  FOR SELECT
  TO authenticated
  USING (
    EXISTS (
      SELECT 1 FROM wearers w
      INNER JOIN users u ON u.safeloop_account_id = w.safeloop_account_id
      WHERE w.id = caregiver_wearer_assignments.wearer_id
      AND u.auth_user_id = auth.uid()
    )
  );

-- Allow authenticated admins to INSERT assignments for wearers in their account
CREATE POLICY "Admins can create assignments for wearers in their account"
  ON caregiver_wearer_assignments
  FOR INSERT
  TO authenticated
  WITH CHECK (
    EXISTS (
      SELECT 1 FROM wearers w
      INNER JOIN users u ON u.safeloop_account_id = w.safeloop_account_id
      WHERE w.id = caregiver_wearer_assignments.wearer_id
      AND u.auth_user_id = auth.uid()
      AND u.user_type = 'caregiver_admin'
    )
  );

-- Allow authenticated admins to DELETE assignments for wearers in their account
CREATE POLICY "Admins can delete assignments for wearers in their account"
  ON caregiver_wearer_assignments
  FOR DELETE
  TO authenticated
  USING (
    EXISTS (
      SELECT 1 FROM wearers w
      INNER JOIN users u ON u.safeloop_account_id = w.safeloop_account_id
      WHERE w.id = caregiver_wearer_assignments.wearer_id
      AND u.auth_user_id = auth.uid()
      AND u.user_type = 'caregiver_admin'
    )
  );

-- Allow authenticated admins to UPDATE assignments for wearers in their account
CREATE POLICY "Admins can update assignments for wearers in their account"
  ON caregiver_wearer_assignments
  FOR UPDATE
  TO authenticated
  USING (
    EXISTS (
      SELECT 1 FROM wearers w
      INNER JOIN users u ON u.safeloop_account_id = w.safeloop_account_id
      WHERE w.id = caregiver_wearer_assignments.wearer_id
      AND u.auth_user_id = auth.uid()
      AND u.user_type = 'caregiver_admin'
    )
  )
  WITH CHECK (
    EXISTS (
      SELECT 1 FROM wearers w
      INNER JOIN users u ON u.safeloop_account_id = w.safeloop_account_id
      WHERE w.id = caregiver_wearer_assignments.wearer_id
      AND u.auth_user_id = auth.uid()
      AND u.user_type = 'caregiver_admin'
    )
  );
