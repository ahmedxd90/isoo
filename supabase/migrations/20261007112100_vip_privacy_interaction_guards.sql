create or replace function public.saki_block_hidden_interaction()
returns trigger language plpgsql security definer set search_path = public
as $$
declare target_id uuid; hidden boolean; other_hidden boolean;
begin
  if tg_table_name = 'follows' then
    target_id := new.following_id;
    select coalesce(p.identity_hidden,false) and public.saki_active_vip_level(p.id) >= 11 into hidden from public.profiles p where p.id = target_id;
    if hidden and new.follower_id is distinct from target_id then raise exception 'hidden_identity_no_follow'; end if;
  elsif tg_table_name = 'conversation_members' then
    select exists(select 1 from public.conversation_members cm join public.profiles p on p.id=cm.user_id where cm.conversation_id=new.conversation_id and cm.user_id <> new.user_id and coalesce(p.identity_hidden,false) and public.saki_active_vip_level(p.id) >= 11) into other_hidden;
    if other_hidden then raise exception 'hidden_identity_no_chat'; end if;
  elsif tg_table_name = 'messages' then
    select exists(select 1 from public.conversation_members cm join public.profiles p on p.id=cm.user_id where cm.conversation_id=new.conversation_id and cm.user_id <> auth.uid() and coalesce(p.identity_hidden,false) and public.saki_active_vip_level(p.id) >= 11) into other_hidden;
    if other_hidden then raise exception 'hidden_identity_no_chat'; end if;
  end if;
  return new;
end;
$$;

drop trigger if exists saki_hidden_follow_guard on public.follows;
create trigger saki_hidden_follow_guard before insert on public.follows for each row execute function public.saki_block_hidden_interaction();
drop trigger if exists saki_hidden_conversation_guard on public.conversation_members;
create trigger saki_hidden_conversation_guard before insert on public.conversation_members for each row execute function public.saki_block_hidden_interaction();
drop trigger if exists saki_hidden_message_guard on public.messages;
create trigger saki_hidden_message_guard before insert on public.messages for each row execute function public.saki_block_hidden_interaction();
revoke all on function public.saki_block_hidden_interaction() from public;
grant execute on function public.saki_block_hidden_interaction() to authenticated;
