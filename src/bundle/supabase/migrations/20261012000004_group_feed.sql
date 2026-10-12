-- Cohort group feed: posts, comments on posts, and cheers.

create table public.group_posts (
  id uuid primary key default gen_random_uuid(),
  cohort_id uuid not null references public.cohorts (id) on delete cascade,
  author_id uuid not null references public.profiles (id) on delete cascade,
  post_kind public.post_kind not null default 'manual',
  -- Set for automatic check-in posts ("Morning done").
  session_id uuid references public.sessions (id) on delete set null,
  body text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  check (post_kind = 'check_in' or length(trim(body)) > 0)
);

create index group_posts_cohort_created_index on public.group_posts (cohort_id, created_at desc);

create table public.group_comments (
  id uuid primary key default gen_random_uuid(),
  post_id uuid not null references public.group_posts (id) on delete cascade,
  author_id uuid not null references public.profiles (id) on delete cascade,
  body text not null check (length(trim(body)) > 0),
  created_at timestamptz not null default now()
);

create index group_comments_post_index on public.group_comments (post_id, created_at);

create table public.group_cheers (
  post_id uuid not null references public.group_posts (id) on delete cascade,
  user_id uuid not null references public.profiles (id) on delete cascade,
  created_at timestamptz not null default now(),
  primary key (post_id, user_id)
);
