-- Programmes, their breath-hold protocol, cohorts and enrolments.

create table public.programs (
  id uuid primary key default gen_random_uuid(),
  name text not null,
  description text,
  duration_weeks smallint not null check (duration_weeks > 0),
  -- A cohort can run a tweaked copy of a programme without editing the original.
  parent_program_id uuid references public.programs (id) on delete set null,
  version smallint not null default 1,
  is_published boolean not null default false,
  created_at timestamptz not null default now()
);

create table public.program_blocks (
  id uuid primary key default gen_random_uuid(),
  program_id uuid not null references public.programs (id) on delete cascade,
  name text not null,
  week_start smallint not null check (week_start > 0),
  week_end smallint not null,
  check (week_end >= week_start)
);

create table public.protocol_steps (
  id uuid primary key default gen_random_uuid(),
  program_id uuid not null references public.programs (id) on delete cascade,
  week_number smallint not null check (week_number > 0),
  -- Null slot means the step applies to every slot that week.
  slot text references public.session_slots (id),
  step_order smallint not null check (step_order > 0),
  step_type public.protocol_step_type not null,
  duration_seconds integer check (duration_seconds > 0),
  instructions text,
  unique nulls not distinct (program_id, week_number, slot, step_order)
);

create table public.cohorts (
  id uuid primary key default gen_random_uuid(),
  program_id uuid not null references public.programs (id) on delete restrict,
  name text not null,
  starts_on date not null,
  created_by uuid references public.profiles (id) on delete set null,
  created_at timestamptz not null default now()
);

-- Membership history. Dates decide which of a member's data shows in which cohort.
create table public.cohort_members (
  id uuid primary key default gen_random_uuid(),
  cohort_id uuid not null references public.cohorts (id) on delete cascade,
  user_id uuid not null references public.profiles (id) on delete cascade,
  role public.cohort_role not null default 'member',
  -- Members choose to join the group feed, then choose to share check-ins. Both
  -- start off. Coaches are always in the group.
  in_group boolean not null default false,
  share_to_group boolean not null default false,
  joined_on date not null default current_date,
  left_on date,
  check (left_on is null or left_on >= joined_on)
);

create unique index cohort_members_one_active_per_cohort
  on public.cohort_members (cohort_id, user_id)
  where left_on is null;

-- A member's run through a programme. Week number is derived from started_on,
-- so swapping cohorts never resets progress.
create table public.enrolments (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references public.profiles (id) on delete cascade,
  program_id uuid not null references public.programs (id) on delete restrict,
  started_on date not null default current_date,
  status public.enrolment_status not null default 'active',
  created_at timestamptz not null default now()
);

create index enrolments_user_id_index on public.enrolments (user_id);
