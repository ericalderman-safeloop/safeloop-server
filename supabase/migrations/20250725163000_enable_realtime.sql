-- Enable real-time for devices table to ensure device verification updates are broadcast
-- This ensures that when is_verified changes from false to true, the real-time subscription detects it

-- Enable real-time on devices table
ALTER PUBLICATION supabase_realtime ADD TABLE devices;

-- Also ensure wearers table has real-time enabled
ALTER PUBLICATION supabase_realtime ADD TABLE wearers;