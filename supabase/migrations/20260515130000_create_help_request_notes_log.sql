-- Create help_request_notes_log table
-- Tracks every version of Assistance Notes for each help request

CREATE TABLE IF NOT EXISTS help_request_notes_log (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    help_request_id UUID NOT NULL REFERENCES help_requests(id) ON DELETE CASCADE,
    notes TEXT,
    changed_by_user_id UUID REFERENCES users(id) ON DELETE SET NULL,
    changed_by_display_name TEXT NOT NULL DEFAULT 'System',
    changed_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT NOW(),
    created_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT NOW()
);

-- Indexes
CREATE INDEX idx_notes_log_help_request ON help_request_notes_log(help_request_id, changed_at ASC);

-- RLS
ALTER TABLE help_request_notes_log ENABLE ROW LEVEL SECURITY;

-- Caregivers in the same account can view notes log
CREATE POLICY "Caregivers can view notes log for their account"
ON help_request_notes_log FOR SELECT
TO authenticated
USING (
    help_request_id IN (
        SELECT hr.id
        FROM help_requests hr
        JOIN wearers w ON w.id = hr.wearer_id
        WHERE w.safeloop_account_id = get_user_safeloop_account_id()
    )
);

-- Caregivers in the same account can insert notes log entries
CREATE POLICY "Caregivers can insert notes log for their account"
ON help_request_notes_log FOR INSERT
TO authenticated
WITH CHECK (
    help_request_id IN (
        SELECT hr.id
        FROM help_requests hr
        JOIN wearers w ON w.id = hr.wearer_id
        WHERE w.safeloop_account_id = get_user_safeloop_account_id()
    )
);

-- Grant permissions
GRANT SELECT, INSERT ON help_request_notes_log TO authenticated;

COMMENT ON TABLE help_request_notes_log IS 'Audit log of all changes to help request assistance notes';
