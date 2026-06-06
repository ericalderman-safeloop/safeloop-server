-- Heartbeat now reports the watch battery so caregivers can see it on the
-- Wearers page. battery_level (0-100) already exists on devices; add a
-- battery_state column so the UI can distinguish "23% and discharging" from
-- "23% and on the charger" (very different urgency).
ALTER TABLE devices
ADD COLUMN IF NOT EXISTS battery_state TEXT
    CHECK (battery_state IN ('unknown', 'unplugged', 'charging', 'full'));
