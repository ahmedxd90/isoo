alter table public.room_mutes add column if not exists mute_voice boolean not null default true;
alter table public.room_mutes add column if not exists mute_chat boolean not null default true;
update public.room_mutes set mute_voice=true,mute_chat=true where mute_voice is null or mute_chat is null;

drop policy if exists room_mutes_manage on public.room_mutes;
create policy room_mutes_manage on public.room_mutes for all to authenticated using (
  exists(select 1 from public.rooms r where r.id=room_mutes.room_id and r.owner_id=auth.uid())
  or exists(select 1 from public.room_moderators rm where rm.room_id=room_mutes.room_id and rm.user_id=auth.uid())
) with check (
  exists(select 1 from public.rooms r where r.id=room_mutes.room_id and r.owner_id=auth.uid())
  or exists(select 1 from public.room_moderators rm where rm.room_id=room_mutes.room_id and rm.user_id=auth.uid())
);
drop policy if exists room_bans_manage on public.room_bans;
create policy room_bans_manage on public.room_bans for all to authenticated using (
  exists(select 1 from public.rooms r where r.id=room_bans.room_id and r.owner_id=auth.uid())
  or exists(select 1 from public.room_moderators rm where rm.room_id=room_bans.room_id and rm.user_id=auth.uid())
) with check (
  exists(select 1 from public.rooms r where r.id=room_bans.room_id and r.owner_id=auth.uid())
  or exists(select 1 from public.room_moderators rm where rm.room_id=room_bans.room_id and rm.user_id=auth.uid())
);
