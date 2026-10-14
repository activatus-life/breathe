-- Triggers: new-user setup, base score, automatic check-in posts, guards.

create function public.set_updated_at()
returns trigger
language plpgsql set search_path = ''
as $$
begin
  new.updated_at = now();
  return new;
end;
$$;

create trigger profiles_set_updated_at before update on public.profiles
  for each row execute function public.set_updated_at();
create trigger user_settings_set_updated_at before update on public.user_settings
  for each row execute function public.set_updated_at();
create trigger group_posts_set_updated_at before update on public.group_posts
  for each row execute function public.set_updated_at();

-- Email sign-in creates the auth user; this seeds everything the app expects.
-- Email sign-in carries no name, so display_name starts empty and the app asks for it.
create function public.handle_new_user()
returns trigger
language plpgsql security definer set search_path = ''
as $$
begin
  insert into public.profiles (id, display_name, avatar_url)
  values (
    new.id,
    coalesce(new.raw_user_meta_data ->> 'full_name', new.raw_user_meta_data ->> 'name', ''),
    new.raw_user_meta_data ->> 'avatar_url'
  );

  insert into public.user_settings (user_id) values (new.id);

  insert into public.session_reminders (user_id, slot, reminder_time)
  select new.id, slot.id, slot.default_reminder_time
  from public.session_slots as slot
  where slot.is_active;

  return new;
end;
$$;

create trigger on_auth_user_created after insert on auth.users
  for each row execute function public.handle_new_user();

-- Keeps sessions.base_score in step with its holds.
create function public.refresh_session_base_score()
returns trigger
language plpgsql security definer set search_path = ''
as $$
declare
  affected_session_id uuid := coalesce(new.session_id, old.session_id);
begin
  update public.sessions
  set base_score = public.calculate_base_score(affected_session_id)
  where id = affected_session_id;
  return null;
end;
$$;

create trigger session_holds_refresh_base_score
  after insert or update or delete on public.session_holds
  for each row execute function public.refresh_session_base_score();

-- When a session is finished, post "<slot> done" to every cohort group the member
-- has joined and shares with, for the programme that session belongs to.
create function public.post_check_in_on_session_done()
returns trigger
language plpgsql security definer set search_path = ''
as $$
begin
  if new.status <> 'done' or old.status = 'done' then
    return new;
  end if;

  insert into public.group_posts (cohort_id, author_id, post_kind, session_id)
  select membership.cohort_id, new.user_id, 'check_in', new.id
  from public.cohort_members as membership
  join public.cohorts as cohort on cohort.id = membership.cohort_id
  join public.enrolments as enrolment on enrolment.id = new.enrolment_id
  where membership.user_id = new.user_id
    and membership.role = 'member'
    and membership.left_on is null
    and membership.in_group
    and membership.share_to_group
    and cohort.program_id = enrolment.program_id;

  return new;
end;
$$;

create trigger sessions_post_check_in
  after update of status on public.sessions
  for each row execute function public.post_check_in_on_session_done();

-- Members may only join or leave the group, change their sharing toggle, or leave the
-- cohort. Everything else is admin-only.
create function public.guard_cohort_member_changes()
returns trigger
language plpgsql set search_path = ''
as $$
begin
  if public.is_admin() then
    return new;
  end if;

  if new.cohort_id <> old.cohort_id
    or new.user_id <> old.user_id
    or new.role <> old.role
    or new.joined_on <> old.joined_on then
    raise exception 'Only an admin can change cohort membership details';
  end if;

  return new;
end;
$$;

create trigger cohort_members_guard before update on public.cohort_members
  for each row execute function public.guard_cohort_member_changes();

-- Stops members promoting themselves to admin.
revoke update on public.profiles from authenticated;
grant update (display_name, avatar_url, timezone) on public.profiles to authenticated;
