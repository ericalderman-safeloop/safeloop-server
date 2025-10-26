-- Create location_updates table for real-time position tracking
-- Stores continuous location updates from wearers during active help requests

CREATE TABLE IF NOT EXISTS location_updates (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    help_request_id UUID REFERENCES help_requests(id) ON DELETE CASCADE NOT NULL,
    wearer_id UUID REFERENCES wearers(id) ON DELETE CASCADE NOT NULL,
    latitude NUMERIC(10, 8) NOT NULL,
    longitude NUMERIC(11, 8) NOT NULL,
    accuracy NUMERIC(10, 2),
    altitude NUMERIC(10, 2),
    speed NUMERIC(10, 2),
    heading NUMERIC(5, 2),
    timestamp TIMESTAMP WITH TIME ZONE DEFAULT NOW() NOT NULL,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW() NOT NULL
);

-- Index for querying location updates by help request
CREATE INDEX idx_location_updates_help_request ON location_updates(help_request_id, timestamp DESC);

-- Index for querying location updates by wearer
CREATE INDEX idx_location_updates_wearer ON location_updates(wearer_id, timestamp DESC);

-- Enable real-time updates for this table
ALTER TABLE location_updates REPLICA IDENTITY FULL;

-- RLS Policies
ALTER TABLE location_updates ENABLE ROW LEVEL SECURITY;

-- Caregivers can view location updates for wearers they're assigned to
CREATE POLICY "Caregivers can view location updates for their wearers"
ON location_updates FOR SELECT
USING (
    wearer_id IN (
        SELECT cwa.wearer_id
        FROM caregiver_wearer_assignments cwa
        JOIN users u ON u.id = cwa.caregiver_user_id
        WHERE u.auth_user_id = auth.uid()
        UNION
        SELECT w.id
        FROM wearers w
        WHERE w.safeloop_account_id = get_user_safeloop_account_id()
        AND is_caregiver_admin()
    )
);

-- Service role can insert location updates (from Edge Function)
CREATE POLICY "Service role can insert location updates"
ON location_updates FOR INSERT
TO service_role
WITH CHECK (true);

-- Grant permissions
GRANT SELECT ON location_updates TO authenticated;
GRANT INSERT ON location_updates TO service_role;

COMMENT ON TABLE location_updates IS 'Real-time location tracking for wearers during active help requests';
