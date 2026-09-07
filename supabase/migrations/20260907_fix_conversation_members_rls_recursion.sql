create or replace function public.is_private_conversation_member(p_conversation_id uuid)
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select exists (
    select 1
    from public.conversation_members cm
    where cm.conversation_id = p_conversation_id
      and cm.user_id = auth.uid()
  );
$$;

grant execute on function public.is_private_conversation_member(uuid) to authenticated;

drop policy if exists "conversation members" on public.conversation_members;
drop policy if exists "saki_conversation_members_select" on public.conversation_members;
drop policy if exists "saki_conversations_select" on public.conversations;

create policy "saki_conversations_select"
on public.conversations
for select
using (public.is_private_conversation_member(id));

create policy "saki_conversation_members_select"
on public.conversation_members
for select
using (public.is_private_conversation_member(conversation_id));
