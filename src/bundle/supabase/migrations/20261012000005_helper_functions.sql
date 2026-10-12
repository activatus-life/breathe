-- Access helpers used by row level security policies.
-- Security definer so policies can check membership without recursive policy lookups.

create function public.is_admin()
returns boolean
language sql stable security definer set search_path = ''
as $$
  select exists (
    select 1 from public.profiles
    where id = auth.uid() and app_role = 'admin'
  );
$$;

create function public.is_active_cohort_member(target_cohort_id uuid)
returns boolean
language sql stable security definer set search_path = ''
as $$
  select exists (
    select 1 from public.cohort_members
    where cohort_id = target_cohort_id
      and user_id = auth.uid()
      and left_on is null
  );
$$;

create function public.is_cohort_coach(target_cohort_id uuid)
returns boolean
language sql stable security definer set search_path = ''
as $$
  select exists (
    select 1 from public.cohort_members
    where cohort_id = target_cohort_id
      and user_id = auth.uid()
      and role = 'coach'
      and left_on is null
  );
$$;

-- A coach sees a member's data only for dates the member was in the coach's cohort.
create function public.coach_can_view_member(member_id uuid, on_date date)
returns boolean
language sql stable security definer set search_path = ''
as $$
  select exists (
    select 1
    from public.cohort_members as coach
    join public.cohort_members as member on member.cohort_id = coach.cohort_id
    where coach.user_id = auth.uid()
      and coach.role = 'coach'
      and coach.left_on is null
      and member.user_id = member_id
      and member.role = 'member'
      and on_date >= member.joined_on
      and (member.left_on is null or on_date <= member.left_on)
  );
$$;

-- True when the caller and another person are both currently in the same cohort.
create function public.shares_active_cohort(other_user_id uuid)
returns boolean
language sql stable security definer set search_path = ''
as $$
  select exists (
    select 1
    from public.cohort_members as mine
    join public.cohort_members as theirs on theirs.cohort_id = mine.cohort_id
    where mine.user_id = auth.uid()
      and mine.left_on is null
      and theirs.user_id = other_user_id
      and theirs.left_on is null
  );
$$;

-- Lets members show "6 members" without being able to list who they are.
create function public.cohort_member_count(target_cohort_id uuid)
returns integer
language sql stable security definer set search_path = ''
as $$
  select case
    when public.is_active_cohort_member(target_cohort_id) or public.is_admin() then (
      select count(*)::integer from public.cohort_members
      where cohort_id = target_cohort_id and role = 'member' and left_on is null
    )
  end;
$$;

-- Placeholder formula: best hold in seconds. Replace when the real formula is known.
create function public.calculate_base_score(target_session_id uuid)
returns integer
language sql stable set search_path = ''
as $$
  select max(duration_seconds) from public.session_holds
  where session_id = target_session_id;
$$;
