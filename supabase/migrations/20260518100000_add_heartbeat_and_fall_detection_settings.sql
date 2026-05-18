-- watch_heartbeats: tracks last ping from each watch + stores APNs token for push
CREATE TABLE IF NOT EXISTS watch_heartbeats (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    wearer_device_id TEXT NOT NULL UNIQUE,
    last_seen TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    push_token TEXT,          -- watchOS APNs device token
    alert_sent_at TIMESTAMPTZ, -- last time a stale-heartbeat alert was sent
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

ALTER TABLE watch_heartbeats ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Allow anon upsert on watch_heartbeats"
    ON watch_heartbeats FOR ALL
    USING (true) WITH CHECK (true);

-- fall_detection_settings: sensitivity per wearer, 'GLOBAL' = default for all
CREATE TABLE IF NOT EXISTS fall_detection_settings (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    wearer_device_id TEXT NOT NULL UNIQUE, -- 'GLOBAL' = global default
    sensitivity TEXT NOT NULL DEFAULT 'medium'
        CHECK (sensitivity IN ('low', 'medium', 'high')),
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

ALTER TABLE fall_detection_settings ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Allow service role full access on fall_detection_settings"
    ON fall_detection_settings FOR ALL
    USING (true) WITH CHECK (true);

-- Seed the global default row
INSERT INTO fall_detection_settings (wearer_device_id, sensitivity)
VALUES ('GLOBAL', 'medium')
ON CONFLICT (wearer_device_id) DO NOTHING;
