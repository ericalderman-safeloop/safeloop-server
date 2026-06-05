-- Per-account default fall detection mode applied to newly created wearers.
-- Existing wearers keep their current mode; only the createWearer flow reads this.
ALTER TABLE safeloop_accounts
ADD COLUMN IF NOT EXISTS default_fall_detection_mode TEXT NOT NULL DEFAULT 'apple'
    CHECK (default_fall_detection_mode IN ('apple', 'custom'));
