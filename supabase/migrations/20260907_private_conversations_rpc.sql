drop function if exists public.create_private_conversation(uuid);

create or replace function public.create_private_conversation(p_other_user_id uuid)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  v_conversation_id uuid;
  v_user_id uuid := auth.uid();
begin
  if v_user_id is null then
    raise exception 'not_authenticated';
  end if;

  if p_other_user_id is null or p_other_user_id = v_user_id then
    raise exception 'invalid_recipient';
  end if;

  select c.id
    into v_conversation_id
  from conversations c
  join conversation_members mine
    on mine.conversation_id = c.id
   and mine.user_id = v_user_id
  join conversation_members other
    on other.conversation_id = c.id
   and other.user_id = p_other_user_id
  order by c.updated_at desc
  limit 1;

  if v_conversation_id is null then
    insert into conversations (created_by)
    values (v_user_id)
    returning id into v_conversation_id;

    insert into conversation_members (conversation_id, user_id)
    values
      (v_conversation_id, v_user_id),
      (v_conversation_id, p_other_user_id);
  end if;

  return jsonb_build_object('id', v_conversation_id);
end;
$$;

grant execute on function public.create_private_conversation(uuid) to authenticated;
