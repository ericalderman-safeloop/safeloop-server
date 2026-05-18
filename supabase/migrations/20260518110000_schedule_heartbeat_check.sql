-- Schedules a pg_cron job to call the check-heartbeats Edge Function every 5 minutes.
-- Uses the anon key (safe — already public in client apps).
-- The Edge Function uses SUPABASE_SERVICE_ROLE_KEY internally for all DB access.

CREATE EXTENSION IF NOT EXISTS pg_net;

SELECT cron.schedule(
    'check-watch-heartbeats',
    '*/5 * * * *',
    $cron$
    SELECT net.http_post(
        url := 'https://jjrgtwkuqtsfoswdiaxs.supabase.co/functions/v1/check-heartbeats',
        headers := '{"Content-Type": "application/json", "Authorization": "Bearer eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Impqcmd0d2t1cXRzZm9zd2RpYXhzIiwicm9sZSI6ImFub24iLCJpYXQiOjE3Nzg4NjU1MDQsImV4cCI6MjA5NDQ0MTUwNH0.1EaE5F7fFGRzxRAyhrksKcS0VTku2b9-IjZKSIpR1gI"}'::jsonb,
        body := '{"triggered_by": "pg_cron"}'::jsonb
    );
    $cron$
);
