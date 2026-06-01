create table if not exists fall_detection_test_sessions (
  id text primary key,
  device_id text not null,
  session_type text not null,
  sensitivity text not null,
  thresholds jsonb not null,
  started_at timestamptz not null,
  ended_at timestamptz,
  events jsonb not null default '[]'::jsonb,
  triggered boolean not null default false,
  created_at timestamptz not null default now()
);

alter table fall_detection_test_sessions enable row level security;

create policy "Service role full access"
  on fall_detection_test_sessions
  for all
  to service_role
  using (true);

create policy "Anon insert"
  on fall_detection_test_sessions
  for insert
  to anon
  with check (true);
