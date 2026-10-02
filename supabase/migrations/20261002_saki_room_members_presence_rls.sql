-- Make public-room presence visible to authenticated clients without a
-- recursive room_members policy. This is required by member lists, room
-- rankings, realtime presence, and the authenticated Agora token function.
alter table public.room_members enable row level security;

revoke select on table public.room_members from public, anon;
grant select on table public.room_members to authenticated;
grant all privileges on table public.room_members to service_role;

drop policy if exists saki_room_members_select on public.room_members;
drop policy if exists saki_room_members_select_active_room on public.room_members;
create policy saki_room_members_select_active_room
  on public.room_members for select to authenticated
  using (
    exists (
      select 1
      from public.rooms r
      where r.id = room_members.room_id
    )
  );

drop policy if exists saki_room_members_insert on public.room_members;
create policy saki_room_members_insert
  on public.room_members for insert to authenticated
  with check (user_id = (select auth.uid()));

drop policy if exists saki_room_members_delete on public.room_members;
create policy saki_room_members_delete
  on public.room_members for delete to authenticated
  using (
    user_id = (select auth.uid())
    or exists (
      select 1
      from public.rooms r
      where r.id = room_members.room_id
        and r.owner_id = (select auth.uid())
    )
  );
