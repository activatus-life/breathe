-- Sessions, holds, check-ins and workouts: the member's own data.

create table public.sessions (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references public.profiles (id) on delete cascade,
  enrolment_id uuid not null references public.enrolments (id) on delete cascade,
  session_date date not null,
  slot text not null references public.session_slots (id),
  status public.session_status not null default 'pending',
  started_at timestamptz,
  completed_at timestamptz,
  elapsed_seconds integer check (elapsed_seconds >= 0),
  start_pulse_bpm smallint check (start_pulse_bpm between 20 and 250),
  end_pulse_bpm smallint check (end_pulse_bpm between 20 and 250),
  -- Written by trigger from session_holds. Stored so Progress reads are fast.
  base_score integer,
  created_at timestamptz not null default now(),
  unique (enrolment_id, session_date, slot)
);

create index sessions_user_date_index on public.sessions (user_id, session_date);

create table public.session_holds (
  id uuid primary key default gen_random_uuid(),
  session_id uuid not null references public.sessions (id) on delete cascade,
  hold_number smallint not null check (hold_number > 0),
  duration_seconds integer not null check (duration_seconds >= 0),
  unique (session_id, hold_number)
);

-- One per session. Mood is asked before the session ("How are you arriving?") and
-- again after it. Sleep is only asked on the first check-in of the day (app rule).
create table public.check_ins (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references public.profiles (id) on delete cascade,
  session_id uuid references public.sessions (id) on delete set null,
  mood_before public.mood not null,
  mood_after public.mood,
  pulse_bpm smallint check (pulse_bpm between 20 and 250),
  sleep_quality public.sleep_quality,
  created_at timestamptz not null default now()
);

create index check_ins_user_created_index on public.check_ins (user_id, created_at);

create table public.workouts (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references public.profiles (id) on delete cascade,
  performed_on date not null,
  workout_type public.workout_type not null,
  duration_minutes smallint check (duration_minutes > 0),
  total_time_seconds integer check (total_time_seconds > 0),
  average_pace_seconds_per_km integer check (average_pace_seconds_per_km > 0),
  stations_completed text,
  perceived_effort smallint check (perceived_effort between 1 and 10),
  average_heart_rate smallint check (average_heart_rate between 20 and 250),
  max_heart_rate smallint check (max_heart_rate between 20 and 250),
  notes text,
  created_at timestamptz not null default now()
);

create index workouts_user_date_index on public.workouts (user_id, performed_on);
