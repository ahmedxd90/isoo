alter table public.messages
  add column if not exists message_type text not null default 'text',
  add column if not exists media_url text,
  add column if not exists media_name text;

create table if not exists public.user_blocks (
  blocker_id uuid not null references public.profiles(id) on delete cascade,
  blocked_id uuid not null references public.profiles(id) on delete cascade,
  created_at timestamptz default now(),
  primary key (blocker_id, blocked_id),
  check (blocker_id <> blocked_id)
);

create table if not exists public.user_reports (
  id uuid primary key default gen_random_uuid(),
  reporter_id uuid not null references public.profiles(id) on delete cascade,
  reported_id uuid not null references public.profiles(id) on delete cascade,
  category text not null check (category in ('sexual', 'advertising', 'abuse', 'other')),
  details text,
  created_at timestamptz default now()
);

alter table public.user_blocks enable row level security;
alter table public.user_reports enable row level security;

drop policy if exists user_blocks_select on public.user_blocks;
drop policy if exists user_blocks_insert on public.user_blocks;
drop policy if exists user_blocks_delete on public.user_blocks;
create policy user_blocks_select on public.user_blocks for select using (auth.uid() = blocker_id or auth.uid() = blocked_id);
create policy user_blocks_insert on public.user_blocks for insert with check (auth.uid() = blocker_id);
create policy user_blocks_delete on public.user_blocks for delete using (auth.uid() = blocker_id);

drop policy if exists user_reports_insert on public.user_reports;
create policy user_reports_insert on public.user_reports for insert with check (auth.uid() = reporter_id);

create index if not exists user_blocks_blocked_idx on public.user_blocks(blocked_id);
create index if not exists user_reports_reported_idx on public.user_reports(reported_id);
