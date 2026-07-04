-- Watch reports its current monitoring state on every heartbeat so caregivers
-- can distinguish "watch is offline" from "wearer is driving" (monitoring
-- intentionally paused). DrivingDetector on the watch pauses fall detection
-- while CMMotionActivityManager reports .automotive, and check-heartbeats
-- treats 'driving' the same way it treats Apple-mode wearers: no stale alert.
ALTER TABLE devices
ADD COLUMN IF NOT EXISTS monitoring_state TEXT
    CHECK (monitoring_state IN ('active', 'driving', 'sos'));
