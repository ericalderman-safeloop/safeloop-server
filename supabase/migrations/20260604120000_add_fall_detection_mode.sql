ALTER TABLE wearers
ADD COLUMN IF NOT EXISTS fall_detection_mode TEXT NOT NULL DEFAULT 'apple'
    CHECK (fall_detection_mode IN ('apple', 'custom'));
