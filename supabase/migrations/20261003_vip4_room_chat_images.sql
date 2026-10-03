-- VIP4+ room images: enforce the restriction server-side.
drop policy if exists "saki_room_messages_insert" on public.room_messages;
drop policy if exists "saki_room_messages_insert_vip_images" on public.room_messages;
create policy "saki_room_messages_insert_vip_images" on public.room_messages
for insert with check (
  auth.uid() = sender_id
  and (
    message_type <> 'image'
    or exists (
      select 1 from public.profiles p
      where p.id = auth.uid() and coalesce(p.vip_level, 0) >= 4
    )
  )
  and (
    exists (select 1 from public.room_members rm where rm.room_id = room_messages.room_id and rm.user_id = auth.uid())
    or exists (select 1 from public.rooms r where r.id = room_messages.room_id and r.owner_id = auth.uid())
  )
);
