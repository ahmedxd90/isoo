-- Wealth is earned by sending room gifts with gold.
-- Charm is earned by receiving room gifts; one gold spent counts as one XP.
alter table public.saki_account_modules
  add column if not exists wealth_xp bigint not null default 0,
  add column if not exists wealth_level integer not null default 0,
  add column if not exists charm_xp bigint not null default 0,
  add column if not exists charm_level integer not null default 0;

alter table public.profiles
  add column if not exists wealth_xp bigint not null default 0,
  add column if not exists wealth_level integer not null default 0,
  add column if not exists charm_xp bigint not null default 0,
  add column if not exists charm_level integer not null default 0;

create or replace function public.level_from_xp(p_xp numeric, p_kind text)
returns integer
language plpgsql immutable
as $$
declare
  level_no integer := 0;
  required numeric;
begin
  for i in 1..500 loop
    if p_kind = 'wealth' and i = 1 then
      required := 5000;
    elsif p_kind = 'wealth' and i = 2 then
      required := 15000;
    elsif p_kind = 'wealth' then
      required := 15000 * power(2, i - 2);
    else
      required := 20000 * power(2, i - 1);
    end if;
    exit when p_xp < required;
    level_no := i;
  end loop;
  return level_no;
end;
$$;

create or replace function public.sync_user_levels(p_user_id uuid)
returns void
language plpgsql security definer set search_path = public
as $$
declare
  wxp bigint;
  cxp bigint;
  wl integer;
  cl integer;
begin
  select wealth_xp, charm_xp into wxp, cxp
    from public.saki_account_modules where user_id = p_user_id;
  wxp := coalesce(wxp, 0);
  cxp := coalesce(cxp, 0);
  wl := public.level_from_xp(wxp, 'wealth');
  cl := public.level_from_xp(cxp, 'charm');
  update public.saki_account_modules
     set wealth_level = wl, charm_level = cl, updated_at = now()
   where user_id = p_user_id;
  update public.profiles
     set wealth_xp = wxp, wealth_level = wl,
         charm_xp = cxp, charm_level = cl, updated_at = now()
   where id = p_user_id;
end;
$$;

-- Replace the room gift transaction atomically so XP cannot be spoofed by the client.
drop function if exists public.send_room_gift(uuid, uuid, uuid, integer);
create function public.send_room_gift(p_room_id uuid, p_recipient_id uuid, p_gift_id uuid, p_quantity integer default 1)
returns table(gold_coins bigint, gift_name text, total_price bigint, recipient_diamonds bigint)
language plpgsql security definer set search_path = public as $$
declare
  g room_gift_catalog%rowtype;
  v_total bigint;
  v_reward bigint;
  sender_ok boolean;
  recipient_ok boolean;
begin
  if p_quantity is null or p_quantity < 1 or p_quantity > 99 then raise exception 'invalid_quantity'; end if;
  select * into g from public.room_gift_catalog where id = p_gift_id and is_active = true;
  if g.id is null then raise exception 'gift_not_found'; end if;
  select exists(select 1 from public.room_members where room_id = p_room_id and user_id = auth.uid()) into sender_ok;
  select exists(select 1 from public.room_members where room_id = p_room_id and user_id = p_recipient_id) into recipient_ok;
  if not sender_ok then raise exception 'sender_room_member_required'; end if;
  if not recipient_ok and p_recipient_id <> auth.uid() then raise exception 'room_member_required'; end if;
  v_total := g.price * p_quantity;
  v_reward := floor(v_total * 0.60);
  update public.saki_account_modules m
     set gold_coins = m.gold_coins - v_total,
         wealth_xp = m.wealth_xp + v_total,
         updated_at = now()
   where m.user_id = auth.uid() and m.gold_coins >= v_total;
  if not found then raise exception 'insufficient_gold'; end if;
  insert into public.saki_account_modules(user_id, diamonds, charm_xp)
    values(p_recipient_id, v_reward, v_total)
    on conflict(user_id) do update set
      diamonds = public.saki_account_modules.diamonds + excluded.diamonds,
      charm_xp = public.saki_account_modules.charm_xp + excluded.charm_xp,
      updated_at = now();
  insert into public.room_gifts(room_id,sender_id,recipient_id,gift_id,quantity,total_price,recipient_diamonds)
    values(p_room_id,auth.uid(),p_recipient_id,p_gift_id,p_quantity,v_total,v_reward);
  insert into public.room_gift_inventory(user_id,gift_id,quantity)
    values(p_recipient_id,p_gift_id,p_quantity)
    on conflict(user_id,gift_id) do update set quantity = public.room_gift_inventory.quantity + excluded.quantity;
  insert into public.gift_announcements(room_id,sender_id,recipient_id,gift_id,total_price,recipient_diamonds)
    values(p_room_id,auth.uid(),p_recipient_id,p_gift_id,v_total,v_reward);
  perform public.sync_user_levels(auth.uid());
  if p_recipient_id <> auth.uid() then perform public.sync_user_levels(p_recipient_id); end if;
  return query select m.gold_coins,g.name,v_total,v_reward
    from public.saki_account_modules m where m.user_id = auth.uid();
end; $$;
revoke all on function public.level_from_xp(numeric, text) from public;
revoke all on function public.sync_user_levels(uuid) from public;
revoke all on function public.send_room_gift(uuid, uuid, uuid, integer) from public;
grant execute on function public.send_room_gift(uuid, uuid, uuid, integer) to authenticated;
