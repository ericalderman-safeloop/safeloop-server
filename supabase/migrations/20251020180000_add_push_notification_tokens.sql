-- Add push notification token fields to users table
-- This allows storing device tokens for iOS (APNs) and Android (FCM) push notifications

ALTER TABLE users
ADD COLUMN IF NOT EXISTS apns_token TEXT,
ADD COLUMN IF NOT EXISTS fcm_token TEXT,
ADD COLUMN IF NOT EXISTS push_notifications_enabled BOOLEAN DEFAULT true;

-- Add indexes for token lookups
CREATE INDEX IF NOT EXISTS idx_users_apns_token ON users(apns_token) WHERE apns_token IS NOT NULL;
CREATE INDEX IF NOT EXISTS idx_users_fcm_token ON users(fcm_token) WHERE fcm_token IS NOT NULL;

-- Add comments
COMMENT ON COLUMN users.apns_token IS 'Apple Push Notification Service token for iOS devices';
COMMENT ON COLUMN users.fcm_token IS 'Firebase Cloud Messaging token for Android devices';
COMMENT ON COLUMN users.push_notifications_enabled IS 'Whether user has enabled push notifications';
