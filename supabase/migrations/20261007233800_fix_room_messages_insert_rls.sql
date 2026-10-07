-- Allow authenticated room members to create their own room messages,
-- including gift and luck-gift announcements, without opening the table publicly.
drop policy if exists saki_room_messages_insert_vip_images on public.room_messages;

create policy saki_room_messages_insert_authenticated
  on public.room_messages
  for insert
  to authenticated
  with check (
    sender_id = (select auth.uid())
    and (
      exists (
        select 1
        from public.room_members rm
        where rm.room_id = room_messages.room_id
          and rm.user_id = (select auth.uid())
      )
      or exists (
        select 1
        from public.rooms r
        where r.id = room_messages.room_id
          and r.owner_id = (select auth.uid())
      )
    )
    and (
      message_type <> 'image'
      or exists (
        select 1
        from public.profiles p
        where p.id = (select auth.uid())
          and coalesce(p.vip_level, 0) >= 4
      )
    )
  );
