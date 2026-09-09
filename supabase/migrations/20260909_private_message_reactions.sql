create table if not exists public.message_reactions (
  id uuid primary key default gen_random_uuid(),
  message_id uuid not null references public.messages(id) on delete cascade,
  conversation_id uuid not null references public.conversations(id) on delete cascade,
  user_id uuid not null references public.profiles(id) on delete cascade,
  emoji text not null check (emoji in ('😂', '❤️', '😭', '😮')),
  created_at timestamptz not null default now(),
  unique (message_id, user_id)
);

create index if not exists message_reactions_conversation_idx
  on public.message_reactions(conversation_id, created_at);

alter table public.message_reactions enable row level security;

drop policy if exists message_reactions_select on public.message_reactions;
drop policy if exists message_reactions_insert on public.message_reactions;
drop policy if exists message_reactions_update on public.message_reactions;
drop policy if exists message_reactions_delete on public.message_reactions;

create policy message_reactions_select on public.message_reactions for select using (
  exists (
    select 1 from public.conversation_members cm
    where cm.conversation_id = message_reactions.conversation_id
      and cm.user_id = auth.uid()
  )
);

create policy message_reactions_insert on public.message_reactions for insert with check (
  auth.uid() = user_id and exists (
    select 1 from public.conversation_members cm
    where cm.conversation_id = message_reactions.conversation_id
      and cm.user_id = auth.uid()
  )
);

create policy message_reactions_update on public.message_reactions for update using (
  auth.uid() = user_id
) with check (auth.uid() = user_id);

create policy message_reactions_delete on public.message_reactions for delete using (
  auth.uid() = user_id
);

alter table public.message_reactions replica identity full;

do $$
begin
  if not exists (
    select 1 from pg_publication_tables
    where pubname = 'supabase_realtime'
      and schemaname = 'public'
      and tablename = 'message_reactions'
  ) then
    alter publication supabase_realtime add table public.message_reactions;
  end if;
end $$;
