alter table public.room_messages add column if not exists message_type text not null default 'chat';
alter table public.room_messages add column if not exists payload jsonb not null default '{}'::jsonb;

 drop policy if exists "saki_room_messages_delete_owner" on public.room_messages;
create policy "saki_room_messages_delete_owner" on public.room_messages for delete using (
  auth.uid() = sender_id or exists (select 1 from public.rooms r where r.id = room_messages.room_id and r.owner_id = auth.uid())
);
