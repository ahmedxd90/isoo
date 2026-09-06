create table if not exists public.pk_battles (
  id uuid primary key default gen_random_uuid(),
  room_id uuid not null references public.rooms(id) on delete cascade,
  channel_name text not null,
  host_id uuid not null references public.profiles(id),
  opponent_id uuid references public.profiles(id),
  status text not null default 'pending' check (status in ('pending','active','finished','cancelled')),
  host_score bigint not null default 0 check (host_score >= 0),
  opponent_score bigint not null default 0 check (opponent_score >= 0),
  duration_seconds integer not null default 300 check (duration_seconds between 30 and 3600),
  started_at timestamptz,
  ends_at timestamptz,
  winner_id uuid references public.profiles(id),
  created_at timestamptz not null default now()
);
create index if not exists pk_battles_room_status_idx on public.pk_battles(room_id, status, created_at desc);
alter table public.pk_battles enable row level security;
drop policy if exists pk_battles_read_authenticated on public.pk_battles;
create policy pk_battles_read_authenticated on public.pk_battles for select to authenticated using (true);
drop policy if exists pk_battles_insert_host on public.pk_battles;
create policy pk_battles_insert_host on public.pk_battles for insert to authenticated with check (host_id = auth.uid());

create or replace function public.start_pk_battle(p_room_id uuid, p_channel_name text, p_duration_seconds integer default 300)
returns public.pk_battles language plpgsql security definer set search_path = public as $$
declare result public.pk_battles;
begin
  if auth.uid() is null then raise exception 'not_authenticated'; end if;
  if not exists (select 1 from public.rooms where id = p_room_id and owner_id = auth.uid()) then raise exception 'room_owner_required'; end if;
  if exists (select 1 from public.pk_battles where room_id = p_room_id and status in ('pending','active')) then raise exception 'pk_already_active'; end if;
  insert into public.pk_battles(room_id, channel_name, host_id, duration_seconds) values (p_room_id, p_channel_name, auth.uid(), greatest(30, least(p_duration_seconds, 3600))) returning * into result;
  return result;
end; $$;

create or replace function public.accept_pk_battle(p_battle_id uuid)
returns public.pk_battles language plpgsql security definer set search_path = public as $$
declare result public.pk_battles;
begin
  if auth.uid() is null then raise exception 'not_authenticated'; end if;
  update public.pk_battles set opponent_id = auth.uid(), status = 'active', started_at = now(), ends_at = now() + make_interval(secs => duration_seconds) where id = p_battle_id and status = 'pending' and host_id <> auth.uid() returning * into result;
  if result.id is null then raise exception 'pk_not_available'; end if;
  return result;
end; $$;

create or replace function public.add_pk_points(p_battle_id uuid, p_points bigint)
returns public.pk_battles language plpgsql security definer set search_path = public as $$
declare result public.pk_battles;
begin
  if auth.uid() is null or p_points <= 0 then raise exception 'invalid_points'; end if;
  update public.pk_battles set host_score = case when host_id = auth.uid() then host_score + p_points else host_score end, opponent_score = case when opponent_id = auth.uid() then opponent_score + p_points else opponent_score end where id = p_battle_id and status = 'active' and (host_id = auth.uid() or opponent_id = auth.uid()) returning * into result;
  if result.id is null then raise exception 'pk_not_active'; end if;
  return result;
end; $$;

create or replace function public.finish_pk_battle(p_battle_id uuid)
returns public.pk_battles language plpgsql security definer set search_path = public as $$
declare result public.pk_battles;
begin
  update public.pk_battles set status = 'finished', winner_id = case when host_score > opponent_score then host_id when opponent_score > host_score then opponent_id else null end where id = p_battle_id and status = 'active' and (host_id = auth.uid() or opponent_id = auth.uid()) returning * into result;
  if result.id is null then raise exception 'pk_not_active'; end if;
  return result;
end; $$;

revoke all on function public.start_pk_battle(uuid,text,integer), public.accept_pk_battle(uuid), public.add_pk_points(uuid,bigint), public.finish_pk_battle(uuid) from public;
grant execute on function public.start_pk_battle(uuid,text,integer), public.accept_pk_battle(uuid), public.add_pk_points(uuid,bigint), public.finish_pk_battle(uuid) to authenticated;
