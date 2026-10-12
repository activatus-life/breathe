-- Row level security: member-owned data. Owner has full access, coach can read
-- within membership dates, admin can read everything.

alter table public.profiles enable row level security;
alter table public.user_settings enable row level security;
alter table public.session_reminders enable row level security;
alter table public.enrolments enable row level security;
alter table public.sessions enable row level security;
alter table public.session_holds enable row level security;
alter table public.check_ins enable row level security;
alter table public.workouts enable row level security;

-- Profiles: cohort mates see names and avatars so the feed can show authors.
create policy "Read own profile or current cohort mates" on public.profiles
  for select to authenticated
  using (
    id = auth.uid()
    or public.shares_active_cohort(id)
    or public.is_admin()
  );
create policy "Update own profile" on public.profiles
  for update to authenticated
  using (id = auth.uid()) with check (id = auth.uid());

-- Settings and reminders: owner only.
create policy "Owner manages settings" on public.user_settings
  for all to authenticated
  using (user_id = auth.uid()) with check (user_id = auth.uid());
create policy "Owner manages reminders" on public.session_reminders
  for all to authenticated
  using (user_id = auth.uid()) with check (user_id = auth.uid());

-- Enrolments: members start programmes themselves (solo is allowed).
create policy "Owner manages enrolments" on public.enrolments
  for all to authenticated
  using (user_id = auth.uid()) with check (user_id = auth.uid());
create policy "Coach and admin read enrolments" on public.enrolments
  for select to authenticated
  using (public.coach_can_view_member(user_id, current_date) or public.is_admin());

-- Sessions.
create policy "Owner manages sessions" on public.sessions
  for all to authenticated
  using (user_id = auth.uid())
  with check (
    user_id = auth.uid()
    and exists (
      select 1 from public.enrolments
      where enrolments.id = enrolment_id and enrolments.user_id = auth.uid()
    )
  );
create policy "Coach and admin read sessions" on public.sessions
  for select to authenticated
  using (public.coach_can_view_member(user_id, session_date) or public.is_admin());

-- Holds inherit access from their session.
create policy "Owner manages holds" on public.session_holds
  for all to authenticated
  using (exists (
    select 1 from public.sessions
    where sessions.id = session_id and sessions.user_id = auth.uid()
  ))
  with check (exists (
    select 1 from public.sessions
    where sessions.id = session_id and sessions.user_id = auth.uid()
  ));
create policy "Coach and admin read holds" on public.session_holds
  for select to authenticated
  using (exists (
    select 1 from public.sessions
    where sessions.id = session_id
      and (public.coach_can_view_member(sessions.user_id, sessions.session_date) or public.is_admin())
  ));

-- Check-ins.
create policy "Owner manages check-ins" on public.check_ins
  for all to authenticated
  using (user_id = auth.uid()) with check (user_id = auth.uid());
create policy "Coach and admin read check-ins" on public.check_ins
  for select to authenticated
  using (public.coach_can_view_member(user_id, created_at::date) or public.is_admin());

-- Workouts.
create policy "Owner manages workouts" on public.workouts
  for all to authenticated
  using (user_id = auth.uid()) with check (user_id = auth.uid());
create policy "Coach and admin read workouts" on public.workouts
  for select to authenticated
  using (public.coach_can_view_member(user_id, performed_on) or public.is_admin());
