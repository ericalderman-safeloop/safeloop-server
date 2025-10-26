-- Replace emergency contact fields with wearer contact phone
-- Remove emergency contact fields that are no longer needed

ALTER TABLE wearers
DROP COLUMN IF EXISTS emergency_contact_name,
DROP COLUMN IF EXISTS emergency_contact_phone,
DROP COLUMN IF EXISTS emergency_contact_relationship;

-- Add wearer contact phone field
ALTER TABLE wearers
ADD COLUMN wearer_contact_phone TEXT;

-- Add index for phone lookups
CREATE INDEX IF NOT EXISTS idx_wearers_contact_phone ON wearers(wearer_contact_phone);
