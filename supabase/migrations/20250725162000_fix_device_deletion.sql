-- Fix device deletion when wearer is removed
-- Set up proper cascading deletion for devices when wearer is deleted

-- First, check current foreign key constraint
-- Then drop and recreate with CASCADE instead of SET NULL

-- Drop existing foreign key constraint (if it exists)
ALTER TABLE devices DROP CONSTRAINT IF EXISTS devices_wearer_id_fkey;

-- Add foreign key constraint with CASCADE deletion
-- When a wearer is deleted, all associated devices should be deleted too
ALTER TABLE devices 
ADD CONSTRAINT devices_wearer_id_fkey 
FOREIGN KEY (wearer_id) 
REFERENCES wearers(id) 
ON DELETE CASCADE;