-- One read for the Group screen. Exposes only the moods and slot from a check-in,
-- never pulse, holds or notes. Runs as the view owner, so access is filtered here.

create view public.group_feed
with (security_invoker = false)
as
select
  post.id,
  post.cohort_id,
  post.post_kind,
  post.body,
  post.created_at,
  post.author_id,
  author.display_name as author_display_name,
  author.avatar_url as author_avatar_url,
  session.slot as check_in_slot,
  check_in.mood_before as check_in_mood_before,
  check_in.mood_after as check_in_mood_after,
  (select count(*)::integer from public.group_cheers as cheer where cheer.post_id = post.id) as cheer_count,
  exists (
    select 1 from public.group_cheers as cheer
    where cheer.post_id = post.id and cheer.user_id = auth.uid()
  ) as cheered_by_me,
  (select count(*)::integer from public.group_comments as comment where comment.post_id = post.id) as comment_count
from public.group_posts as post
join public.profiles as author on author.id = post.author_id
left join public.sessions as session on session.id = post.session_id
left join lateral (
  select mood_before, mood_after from public.check_ins
  where check_ins.session_id = post.session_id
  order by created_at desc
  limit 1
) as check_in on true
where public.is_group_member(post.cohort_id) or public.is_admin();

revoke all on public.group_feed from anon;
grant select on public.group_feed to authenticated;
