-- The Flutter client updates updated_at after inserting a private message.
-- Keep the column grant narrow and allow row updates only for conversation members.
alter table public.conversations enable row level security;

drop policy if exists saki_conversations_update_participant on public.conversations;
create policy saki_conversations_update_participant
  on public.conversations for update to authenticated
  using (private.is_private_conversation_member(id))
  with check (private.is_private_conversation_member(id));

revoke update on table public.conversations from public, anon, authenticated;
revoke update (id, created_at, created_by, updated_at)
  on table public.conversations from public, anon, authenticated;
grant update (updated_at) on table public.conversations to authenticated;
