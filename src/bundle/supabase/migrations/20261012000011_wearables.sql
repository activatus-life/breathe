-- Wearable data, starting with Apple Watch through Apple Health. The layout follows
-- Apple Health: numbers measured over time, sleep by stage, and workouts. Names are
-- plain English, not Apple's identifiers, so Garmin and WHOOP can be added later as
-- new sources without renaming anything.

create type public.health_source as enum ('apple_health', 'manual');
-- Apple measures heart rate variability as SDNN. Garmin and WHOOP use RMSSD, a
-- different number, so each kind gets its own reading type when its source arrives.
create type public.health_reading_type as enum (
  'heart_rate', 'resting_heart_rate', 'heart_rate_variability_sdnn', 'respiratory_rate', 'oxygen_saturation'
);
create type public.sleep_stage as enum ('in_bed', 'asleep', 'awake', 'core', 'deep', 'rem');

-- Which sources a member has connected, and when the app last pulled from each.
create table public.health_connections (
  user_id uuid not null references public.profiles (id) on delete cascade,
  source public.health_source not null,
  connected_at timestamptz not null default now(),
  last_synced_at timestamptz,
  is_enabled boolean not null default true,
  primary key (user_id, source)
);

-- One measurement at a moment or over a span, like Apple Health's quantity samples.
-- Units: bpm for heart rates, ms for variability, breaths_per_minute, percent.
create table public.health_readings (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references public.profiles (id) on delete cascade,
  reading_type public.health_reading_type not null,
  value numeric not null,
  unit text not null,
  started_at timestamptz not null,
  ended_at timestamptz not null,
  source public.health_source not null,
  -- The record's id in its source, so syncing again never saves it twice.
  source_record_id text,
  device_name text,
  created_at timestamptz not null default now(),
  check (ended_at >= started_at),
  unique (user_id, source, source_record_id)
);

create index health_readings_user_type_time_index
  on public.health_readings (user_id, reading_type, started_at);

-- Sleep, one row per stage, like Apple Health's sleep analysis.
create table public.sleep_periods (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references public.profiles (id) on delete cascade,
  stage public.sleep_stage not null,
  started_at timestamptz not null,
  ended_at timestamptz not null,
  source public.health_source not null,
  source_record_id text,
  created_at timestamptz not null default now(),
  check (ended_at > started_at),
  unique (user_id, source, source_record_id)
);

create index sleep_periods_user_time_index on public.sleep_periods (user_id, started_at);

-- Workouts from a watch land in the same table as logged ones.
alter table public.workouts
  add column source public.health_source not null default 'manual',
  add column source_record_id text,
  add column started_at timestamptz,
  add constraint workouts_source_record_unique unique (user_id, source, source_record_id);

alter table public.health_connections enable row level security;
alter table public.health_readings enable row level security;
alter table public.sleep_periods enable row level security;

create policy "Owner manages health connections" on public.health_connections
  for all to authenticated
  using (user_id = auth.uid()) with check (user_id = auth.uid());

create policy "Owner manages health readings" on public.health_readings
  for all to authenticated
  using (user_id = auth.uid()) with check (user_id = auth.uid());
create policy "Coach and admin read health readings" on public.health_readings
  for select to authenticated
  using (public.coach_can_view_member(user_id, started_at::date) or public.is_admin());

create policy "Owner manages sleep periods" on public.sleep_periods
  for all to authenticated
  using (user_id = auth.uid()) with check (user_id = auth.uid());
create policy "Coach and admin read sleep periods" on public.sleep_periods
  for select to authenticated
  using (public.coach_can_view_member(user_id, started_at::date) or public.is_admin());
