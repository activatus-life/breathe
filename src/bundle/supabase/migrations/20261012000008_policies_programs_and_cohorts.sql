-- Row level security: programmes, cohorts and the group feed.

alter table public.session_slots enable row level security;
alter table public.programs enable row level security;
alter table public.program_blocks enable row level security;
alter table public.protocol_steps enable row level security;
alter table public.cohorts enable row level security;
alter table public.cohort_members enable row level security;
alter table public.group_posts enable row level security;
alter table public.group_comments enable row level security;
alter table public.group_cheers enable row level security;

-- Session times: everyone reads, admins add or rename.
create policy "Read session times" on public.session_slots
  for select to authenticated using (true);
create policy "Admin manages session times" on public.session_slots
  for all to authenticated using (public.is_admin()) with check (public.is_admin());

-- Programme content: everyone reads published content, admins write.
create policy "Read published programmes" on public.programs
  for select to authenticated using (is_published or public.is_admin());
create policy "Admin manages programmes" on public.programs
  for all to authenticated using (public.is_admin()) with check (public.is_admin());

create policy "Read published blocks" on public.program_blocks
  for select to authenticated
  using (exists (
    select 1 from public.programs
    where programs.id = program_id and (programs.is_published or public.is_admin())
  ));
create policy "Admin manages blocks" on public.program_blocks
  for all to authenticated using (public.is_admin()) with check (public.is_admin());

create policy "Read published protocol steps" on public.protocol_steps
  for select to authenticated
  using (exists (
    select 1 from public.programs
    where programs.id = program_id and (programs.is_published or public.is_admin())
  ));
create policy "Admin manages protocol steps" on public.protocol_steps
  for all to authenticated using (public.is_admin()) with check (public.is_admin());

-- Cohorts: visible to their members and coach.
create policy "Members read their cohorts" on public.cohorts
  for select to authenticated
  using (public.is_active_cohort_member(id) or public.is_admin());
create policy "Admin manages cohorts" on public.cohorts
  for all to authenticated using (public.is_admin()) with check (public.is_admin());

-- Membership: members see only their own rows; coaches see their roster.
-- Members can join or leave the group and turn sharing on or off (see the guard trigger).
create policy "Read own membership or coached roster" on public.cohort_members
  for select to authenticated
  using (
    user_id = auth.uid()
    or public.is_cohort_coach(cohort_id)
    or public.is_admin()
  );
create policy "Member updates own sharing or leaves" on public.cohort_members
  for update to authenticated
  using (user_id = auth.uid() or public.is_admin())
  with check (user_id = auth.uid() or public.is_admin());
create policy "Admin adds and removes members" on public.cohort_members
  for insert to authenticated with check (public.is_admin());
create policy "Admin deletes memberships" on public.cohort_members
  for delete to authenticated using (public.is_admin());

-- Posts: current group members read and write. Check-in posts come from the trigger only.
create policy "Cohort reads posts" on public.group_posts
  for select to authenticated
  using (public.is_group_member(cohort_id) or public.is_admin());
create policy "Member writes own posts" on public.group_posts
  for insert to authenticated
  with check (
    author_id = auth.uid()
    and post_kind = 'manual'
    and public.is_group_member(cohort_id)
  );
create policy "Author edits own posts" on public.group_posts
  for update to authenticated
  using (author_id = auth.uid()) with check (author_id = auth.uid());
create policy "Author, coach or admin deletes posts" on public.group_posts
  for delete to authenticated
  using (author_id = auth.uid() or public.is_cohort_coach(cohort_id) or public.is_admin());

-- Comments and cheers follow the post's cohort group.
create policy "Cohort reads comments" on public.group_comments
  for select to authenticated
  using (exists (
    select 1 from public.group_posts
    where group_posts.id = post_id
      and (public.is_group_member(group_posts.cohort_id) or public.is_admin())
  ));
create policy "Member writes own comments" on public.group_comments
  for insert to authenticated
  with check (
    author_id = auth.uid()
    and exists (
      select 1 from public.group_posts
      where group_posts.id = post_id and public.is_group_member(group_posts.cohort_id)
    )
  );
create policy "Author deletes own comments" on public.group_comments
  for delete to authenticated using (author_id = auth.uid() or public.is_admin());

create policy "Cohort reads cheers" on public.group_cheers
  for select to authenticated
  using (exists (
    select 1 from public.group_posts
    where group_posts.id = post_id
      and (public.is_group_member(group_posts.cohort_id) or public.is_admin())
  ));
create policy "Member cheers" on public.group_cheers
  for insert to authenticated
  with check (
    user_id = auth.uid()
    and exists (
      select 1 from public.group_posts
      where group_posts.id = post_id and public.is_group_member(group_posts.cohort_id)
    )
  );
create policy "Member removes own cheer" on public.group_cheers
  for delete to authenticated using (user_id = auth.uid());
