-- Per-caregiver preference for the sound played when a help request /
-- fall notification arrives. 'alarm' = siren-style loud loop bundled
-- with the app (safeloop_alarm.caf). 'standard' = system default sound.
--
-- Defaulting to 'alarm' because this is a safety-critical alert; users
-- must deliberately opt out.

ALTER TABLE notification_preferences
ADD COLUMN IF NOT EXISTS help_request_sound TEXT NOT NULL
    DEFAULT 'alarm'
    CHECK (help_request_sound IN ('alarm', 'standard'));
