-- Enums and the member-level tables (profile, settings, reminders).

create type public.app_role as enum ('member', 'admin');
create type public.cohort_role as enum ('member', 'coach');
create type public.session_status as enum ('pending', 'in_progress', 'done', 'skipped');
create type public.mood as enum ('low', 'flat', 'okay', 'good', 'great');
create type public.sleep_quality as enum ('poor', 'fair', 'good', 'great');
create type public.workout_type as enum ('hyrox', 'run', 'strength', 'cycle', 'other');
create type public.post_kind as enum ('manual', 'check_in');
create type public.protocol_step_type as enum ('pulse', 'base', 'hold', 'recovery');
create type public.enrolment_status as enum ('active', 'completed', 'left');

-- One row per auth user. Deleting the auth user cascades through everything.
create table public.profiles (
  id uuid primary key references auth.users (id) on delete cascade,
  display_name text not null default '',
  avatar_url text,
  timezone text not null default 'UTC',
  app_role public.app_role not null default 'member',
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table public.user_settings (
  user_id uuid primary key references public.profiles (id) on delete cascade,
  gentle_nudges boolean not null default true,
  group_activity boolean not null default false,
  weekly_summary boolean not null default true,
  background_audio boolean not null default true,
  audio_volume smallint not null default 60 check (audio_volume between 0 and 100),
  -- Text rather than an enum because the sound list is still being decided.
  background_sound text not null default 'soft_rain',
  updated_at timestamptz not null default now()
);

-- Session times. A table rather than an enum so an admin can add one (noon, night)
-- in the dashboard without an app release. Starts with morning and evening.
create table public.session_slots (
  id text primary key check (id ~ '^[a-z][a-z_]*$'),
  label text not null,
  sort_order smallint not null,
  default_reminder_time time not null,
  is_active boolean not null default true
);

insert into public.session_slots (id, label, sort_order, default_reminder_time) values
  ('morning', 'Morning', 1, '07:00'),
  ('evening', 'Evening', 2, '20:30');

create table public.session_reminders (
  user_id uuid not null references public.profiles (id) on delete cascade,
  slot text not null references public.session_slots (id),
  reminder_time time not null,
  is_enabled boolean not null default true,
  primary key (user_id, slot)
);
