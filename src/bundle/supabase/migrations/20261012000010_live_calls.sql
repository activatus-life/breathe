-- Live breathwork sessions and coaching calls. Today shows the next one, and
-- "Join call" opens join_url in Zoom, Google Meet or similar. The call itself
-- happens outside the app.

create table public.live_calls (
  id uuid primary key default gen_random_uuid(),
  -- Null means the call is open to every member.
  cohort_id uuid references public.cohorts (id) on delete cascade,
  title text not null check (length(trim(title)) > 0),
  starts_at timestamptz not null,
  duration_minutes smallint not null default 60 check (duration_minutes > 0),
  join_url text not null check (join_url ~ '^https://'),
  created_by uuid references public.profiles (id) on delete set null,
  created_at timestamptz not null default now()
);

create index live_calls_starts_at_index on public.live_calls (starts_at);

alter table public.live_calls enable row level security;

create policy "Members read their live calls" on public.live_calls
  for select to authenticated
  using (cohort_id is null or public.is_active_cohort_member(cohort_id) or public.is_admin());
create policy "Admin manages live calls" on public.live_calls
  for all to authenticated using (public.is_admin()) with check (public.is_admin());
