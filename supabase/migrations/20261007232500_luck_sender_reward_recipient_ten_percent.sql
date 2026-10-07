-- Luck gift settlement policy:
-- sender receives the multiplier reward; recipient receives only 10% diamonds.
create or replace function public.send_room_luck_gift(
  p_room_id uuid, p_recipient_id uuid, p_gift_id uuid, p_quantity integer default 1
)
returns table(
  gold_coins bigint,
  gift_name text,
  gift_price bigint,
  multiplier integer,
  reward_gold bigint,
  win_percent smallint,
  announcement_id uuid
)
language plpgsql security definer set search_path=public as $$
declare
  g public.room_gift_catalog%rowtype;
  sender_profile public.profiles%rowtype;
  recipient_profile public.profiles%rowtype;
  r public.rooms%rowtype;
  v_total bigint;
  v_base_price bigint;
  v_recipient_diamonds bigint;
  v_reward bigint := 0;
  v_multiplier integer := 1;
  v_win_percent smallint;
  v_bonus smallint := 0;
  v_roll numeric;
  v_announcement uuid;
  v_payload jsonb;
  v_balance bigint;
begin
  if auth.uid() is null then raise exception 'not_authenticated'; end if;
  if p_quantity is null or p_quantity < 1 or p_quantity > 777 then raise exception 'invalid_quantity'; end if;
  select * into g from public.room_gift_catalog
   where id = p_gift_id and category = 'luck' and is_active = true;
  if g.id is null then raise exception 'luck_gift_not_found'; end if;
  if not exists (select 1 from public.room_members where room_id = p_room_id and user_id = auth.uid()) then raise exception 'sender_room_member_required'; end if;
  if not exists (select 1 from public.room_members where room_id = p_room_id and user_id = p_recipient_id)
     and p_recipient_id <> auth.uid() then raise exception 'room_member_required'; end if;

  select * into r from public.rooms where id = p_room_id;
  select * into sender_profile from public.profiles where id = auth.uid();
  select * into recipient_profile from public.profiles where id = p_recipient_id;
  select coalesce(s.luck_bonus_percent, 0) into v_bonus
    from public.user_luck_settings s where s.user_id = auth.uid();
  v_win_percent := (34 + least(coalesce(v_bonus, 0), 10))::smallint;

  v_base_price := g.price;
  v_total := v_base_price * p_quantity;
  -- The recipient gets only 10% of the paid value as diamonds.
  v_recipient_diamonds := floor(v_total * 0.10);

  -- The sender pays the total cost and is the only possible gold-reward owner.
  update public.saki_account_modules as m
     set gold_coins = m.gold_coins - v_total, updated_at = now()
   where m.user_id = auth.uid() and m.gold_coins >= v_total
   returning m.gold_coins into v_balance;
  if not found then raise exception 'insufficient_gold'; end if;

  v_roll := random() * 100;
  if v_roll < v_win_percent then
    v_roll := random() * 10000;
    if v_roll < 9500 then v_multiplier := 2;
    elsif v_roll < 9900 then v_multiplier := 5;
    elsif v_roll < 9980 then v_multiplier := 10;
    elsif v_roll < 9995 then v_multiplier := 20;
    elsif v_roll < 9999 then v_multiplier := 50;
    elsif v_roll < 9999.5 then v_multiplier := 100;
    elsif v_roll < 9999.9 then v_multiplier := 500;
    else v_multiplier := 1000;
    end if;
    v_reward := v_base_price * v_multiplier;
    update public.saki_account_modules as m
       set gold_coins = m.gold_coins + v_reward, updated_at = now()
     where m.user_id = auth.uid();
  end if;

  insert into public.saki_account_modules(user_id, diamonds)
    values (p_recipient_id, v_recipient_diamonds)
    on conflict (user_id) do update set
      diamonds = public.saki_account_modules.diamonds + excluded.diamonds,
      updated_at = now();

  insert into public.room_gifts(room_id, sender_id, recipient_id, gift_id, quantity, total_price, recipient_diamonds)
    values (p_room_id, auth.uid(), p_recipient_id, p_gift_id, p_quantity, v_total, v_recipient_diamonds);
  insert into public.room_gift_inventory(user_id, gift_id, quantity)
    values (p_recipient_id, p_gift_id, p_quantity)
    on conflict (user_id, gift_id) do update
      set quantity = public.room_gift_inventory.quantity + excluded.quantity;

  v_payload := jsonb_build_object(
    'event_type', 'luck_multiplier', 'gift_id', g.id, 'icon', g.icon,
    'thumbnail_url', g.icon, 'media_url', g.media_url, 'media_type', g.media_type,
    'name', g.name, 'category', 'luck', 'quantity', p_quantity,
    'recipient_id', p_recipient_id, 'recipient_username', recipient_profile.username,
    'recipient_avatar_url', recipient_profile.avatar_url, 'sender_id', auth.uid(),
    'sender_username', sender_profile.username, 'sender_avatar_url', sender_profile.avatar_url,
    'winner_id', auth.uid(), 'winner_username', sender_profile.username,
    'reward_owner', 'sender', 'room_id', p_room_id, 'room_name', r.name,
    'base_gift_price', v_base_price, 'gift_price', v_base_price, 'total_price', v_total,
    'multiplier', v_multiplier, 'reward_gold', v_reward,
    'recipient_diamonds', v_recipient_diamonds, 'recipient_percent', 10,
    'win_percent', v_win_percent, 'flying_luck_banner', v_multiplier > 1
  );

  if v_multiplier > 1 then
    insert into public.gift_announcements(
      room_id, sender_id, recipient_id, gift_id, total_price,
      recipient_diamonds, event_type, multiplier, reward_gold, gift_price
    ) values (
      p_room_id, auth.uid(), p_recipient_id, p_gift_id, v_total,
      v_recipient_diamonds, 'luck_multiplier', v_multiplier, v_reward, v_base_price
    ) returning id into v_announcement;
    insert into public.room_messages(room_id, sender_id, body, message_type, payload)
      values (
        p_room_id, auth.uid(),
        format('%s أرسل هدية الحظ ×%s وحصل على %s عملة ذهبية، والمستقبل حصل على 10%% فقط',
          sender_profile.username, v_multiplier, v_reward),
        'luck_multiplier', v_payload
      );
  else
    insert into public.room_messages(room_id, sender_id, body, message_type, payload)
      values (p_room_id, auth.uid(), format('%s أرسل هدية حظ، والمستقبل حصل على 10%% فقط', sender_profile.username), 'gift', v_payload);
  end if;

  return query select v_balance, g.name, v_base_price, v_multiplier, v_reward, v_win_percent, v_announcement;
end;
$$;

revoke all on function public.send_room_luck_gift(uuid, uuid, uuid, integer) from public;
grant execute on function public.send_room_luck_gift(uuid, uuid, uuid, integer) to authenticated;
