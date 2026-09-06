create table if not exists public.live_broadcasts (
  id uuid primary key default gen_random_uuid(),
  room_id uuid not null references public.rooms(id) on delete cascade,
  host_id uuid not null references public.profiles(id) on delete cascade,
  channel_name text not null unique,
  title text not null,
  avatar_url text,
  status text not null default 'live' check (status in ('live','ended')),
  started_at timestamptz not null default now(),
  ended_at timestamptz
);
create index if not exists live_broadcasts_active_idx on public.live_broadcasts(status, started_at desc);
alter table public.live_broadcasts enable row level security;
drop policy if exists live_broadcasts_read_authenticated on public.live_broadcasts;
create policy live_broadcasts_read_authenticated on public.live_broadcasts for select to authenticated using (true);
drop policy if exists live_broadcasts_insert_host on public.live_broadcasts;
create policy live_broadcasts_insert_host on public.live_broadcasts for insert to authenticated with check (host_id = auth.uid());
drop policy if exists live_broadcasts_update_host on public.live_broadcasts;
create policy live_broadcasts_update_host on public.live_broadcasts for update to authenticated using (host_id = auth.uid()) with check (host_id = auth.uid());
create or replace function public.start_live_broadcast(p_room_id uuid, p_channel_name text, p_title text)
returns public.live_broadcasts language plpgsql security definer set search_path = public as $$
declare result public.live_broadcasts; avatar text;
begin
  if auth.uid() is null then raise exception 'not_authenticated'; end if;
  if not exists (select 1 from public.rooms where id=p_room_id and owner_id=auth.uid() and is_active=true) then raise exception 'room_owner_required'; end if;
  select avatar_url into avatar from public.profiles where id=auth.uid();
  update public.live_broadcasts set status='ended', ended_at=now() where host_id=auth.uid() and status='live';
  insert into public.live_broadcasts(room_id,host_id,channel_name,title,avatar_url) values(p_room_id,auth.uid(),p_channel_name,left(trim(p_title),100),avatar) returning * into result;
  return result;
end; $$;
create or replace function public.end_live_broadcast(p_channel_name text)
returns void language plpgsql security definer set search_path = public as $$
begin
  update public.live_broadcasts set status='ended', ended_at=now() where channel_name=p_channel_name and host_id=auth.uid() and status='live';
end; $$;
revoke all on function public.start_live_broadcast(uuid,text,text), public.end_live_broadcast(text) from public;
grant execute on function public.start_live_broadcast(uuid,text,text), public.end_live_broadcast(text) to authenticated;
