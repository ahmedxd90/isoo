-- Broadcast qualifying buffet wins once as a room-chat message.
create or replace function public.saki_buffet_announce_big_win()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  v_profile record;
  v_room record;
begin
  if new.payout < 1000000 or coalesce(old.payout, 0) >= 1000000 then
    return new;
  end if;

  select username, display_name, avatar_url
  into v_profile
  from public.profiles
  where id = new.user_id;

  for v_room in
    select id, owner_id
    from public.rooms
    where coalesce(is_active, true) = true
  loop
    insert into public.room_messages(
      room_id, sender_id, body, message_type, payload
    ) values (
      v_room.id,
      v_room.owner_id,
      'مبروك لقد ربحت في لعبة بوفيه الأطعمة',
      'buffet_big_win',
      jsonb_build_object(
        'user_id', new.user_id,
        'username', coalesce(v_profile.display_name, v_profile.username, 'مستخدم'),
        'avatar_url', v_profile.avatar_url,
        'profit', new.payout,
        'round_id', new.round_id,
        'food_id', new.food_id,
        'chat_only', true
      )
    );
  end loop;
  return new;
end;
$$;

drop trigger if exists saki_buffet_big_win_chat on public.saki_buffet_bets;
create trigger saki_buffet_big_win_chat
after update of payout on public.saki_buffet_bets
for each row execute function public.saki_buffet_announce_big_win();
