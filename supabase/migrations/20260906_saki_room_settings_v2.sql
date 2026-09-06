alter table public.rooms add column if not exists announcement text;
alter table public.rooms add column if not exists category text not null default 'عام';
alter table public.rooms add column if not exists theme_key text not null default 'default';
alter table public.rooms add column if not exists membership_fee integer not null default 0;
alter table public.rooms add column if not exists reward_rate numeric(5,2) not null default 0;
alter table public.rooms add column if not exists mic_permission text not null default 'everyone';

alter table public.rooms drop constraint if exists rooms_mic_permission_allowed;
alter table public.rooms add constraint rooms_mic_permission_allowed check (mic_permission in ('everyone','followers','moderators','owner'));
alter table public.rooms drop constraint if exists rooms_membership_fee_nonnegative;
alter table public.rooms add constraint rooms_membership_fee_nonnegative check (membership_fee >= 0);
alter table public.rooms drop constraint if exists rooms_reward_rate_allowed;
alter table public.rooms add constraint rooms_reward_rate_allowed check (reward_rate >= 0 and reward_rate <= 100);

create table if not exists public.room_activity_logs (
  id uuid primary key default gen_random_uuid(),
  room_id uuid not null references public.rooms(id) on delete cascade,
  actor_id uuid not null references public.profiles(id) on delete cascade,
  action text not null,
  target_user_id uuid references public.profiles(id) on delete set null,
  metadata jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now()
);
create index if not exists room_activity_logs_room_created_idx on public.room_activity_logs(room_id, created_at desc);
alter table public.room_activity_logs enable row level security;
drop policy if exists room_activity_logs_read on public.room_activity_logs;
create policy room_activity_logs_read on public.room_activity_logs for select using (
  exists (select 1 from public.rooms r where r.id = room_activity_logs.room_id and r.owner_id = auth.uid())
  or exists (select 1 from public.room_moderators m where m.room_id = room_activity_logs.room_id and m.user_id = auth.uid())
);
drop policy if exists room_activity_logs_insert on public.room_activity_logs;
create policy room_activity_logs_insert on public.room_activity_logs for insert with check (
  actor_id = auth.uid() and (
    exists (select 1 from public.rooms r where r.id = room_activity_logs.room_id and r.owner_id = auth.uid())
    or exists (select 1 from public.room_moderators m where m.room_id = room_activity_logs.room_id and m.user_id = auth.uid())
  )
);

-- Owners can manage the complete moderator list, while preserving the existing creator policy.
drop policy if exists room_moderators_owner_manage on public.room_moderators;
create policy room_moderators_owner_manage on public.room_moderators for all using (
  exists (select 1 from public.rooms r where r.id = room_moderators.room_id and r.owner_id = auth.uid())
) with check (
  exists (select 1 from public.rooms r where r.id = room_moderators.room_id and r.owner_id = auth.uid())
);
