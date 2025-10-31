-- Add resolved_by column to help_requests table
-- This tracks which caregiver marked the alert as resolved

ALTER TABLE help_requests
ADD COLUMN resolved_by UUID REFERENCES users(id);

-- Add index for performance
CREATE INDEX idx_help_requests_resolved_by ON help_requests(resolved_by);

-- Add comment for documentation
COMMENT ON COLUMN help_requests.resolved_by IS 'User ID of the caregiver who marked this help request as resolved or false alarm';
