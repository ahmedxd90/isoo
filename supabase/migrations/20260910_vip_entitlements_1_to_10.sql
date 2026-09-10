-- Make the complete VIP 1..10 catalog real at the database boundary.
alter table public.vip_transactions
  drop constraint if exists vip_transactions_vip_level_check;
alter table public.vip_transactions
  add constraint vip_transactions_vip_level_check check (vip_level between 1 and 10);

drop function if exists public.gift_vip(bigint, integer);
create function public.gift_vip(p_saki_id bigint, p_level integer)
returns table(recipient_username text, vip_level integer, vip_expires_at timestamptz, gold_coins bigint)
language plpgsql security definer set search_path = public as $$
declare
  cost bigint;
  target uuid;
  expires timestamptz;
  balance bigint;
begin
  if auth.uid() is null then raise exception 'not_authenticated'; end if;
  if p_level < 1 or p_level > 10 then raise exception 'invalid_vip_level'; end if;
  cost := case p_level
    when 1 then 60000 when 2 then 200000 when 3 then 500000
    when 4 then 1000000 when 5 then 2000000 when 6 then 4000000
    when 7 then 8000000 when 8 then 10000000 when 9 then 12000000
    when 10 then 20000000
  end;
  select id into target from public.profiles where saki_id = p_saki_id for update;
  if target is null then raise exception 'recipient_not_found'; end if;
  if target = auth.uid() then raise exception 'cannot_gift_self'; end if;
  update public.saki_account_modules
    set gold_coins = gold_coins - cost, updated_at = now()
    where user_id = auth.uid() and gold_coins >= cost;
  if not found then raise exception 'insufficient_gold'; end if;
  select coalesce(vip_expires_at, now()) into expires
    from public.profiles where id = target;
  if expires < now() then expires := now(); end if;
  expires := expires + interval '30 days';
  update public.profiles
    set vip_level = greatest(vip_level, p_level), vip_expires_at = expires, updated_at = now()
    where id = target;
  update public.saki_account_modules
    set vip_level = greatest(vip_level, p_level), vip_label = 'VIP ' || p_level, updated_at = now()
    where user_id = target;
  insert into public.vip_transactions(sender_id, recipient_id, vip_level, price, transaction_type)
    values(auth.uid(), target, p_level, cost, 'gift');
  select m.gold_coins into balance from public.saki_account_modules m where m.user_id = auth.uid();
  return query
    select p.username, p.vip_level, p.vip_expires_at, balance
    from public.profiles p where p.id = target;
end; $$;
revoke all on function public.gift_vip(bigint, integer) from public;
grant execute on function public.gift_vip(bigint, integer) to authenticated;

-- The VIP mini-game is a VIP10 entitlement, enforced server-side.
create or replace function public.saki_vip_slot_spin(p_room_id uuid, p_wager bigint)
returns table(spin_id bigint, symbols jsonb, payout bigint, gold_coins bigint)
language plpgsql security definer set search_path = public
as $$
declare
  v_symbols text[] := array['diamond','crown','watermelon','grape','cherry','mango'];
  v_grid text[] := array[]::text[];
  v_paylines int[][] := array[array[1,2,3],array[4,5,6],array[7,8,9],array[1,5,9],array[7,5,3]];
  v_line int[]; v_symbol text; v_payout bigint := 0; v_line_payout bigint;
  v_balance bigint; v_id bigint; v_match boolean; i integer;
begin
  if auth.uid() is null then raise exception 'not_authenticated'; end if;
  if not exists (
    select 1 from public.profiles
    where id = auth.uid() and vip_level >= 10
      and vip_expires_at is not null and vip_expires_at > now()
  ) then raise exception 'vip10_required'; end if;
  if p_room_id is null or not exists(select 1 from public.rooms r where r.id=p_room_id and r.is_active=true) then raise exception 'game_room_not_available'; end if;
  if p_wager not in (10,50,100,500,1000,5000,10000) then raise exception 'invalid_slot_wager'; end if;
  update public.saki_account_modules set gold_coins=gold_coins-p_wager,updated_at=now()
    where user_id=auth.uid() and gold_coins>=p_wager;
  if not found then raise exception 'insufficient_gold'; end if;
  for i in 1..9 loop v_grid:=array_append(v_grid,v_symbols[1+floor(random()*array_length(v_symbols,1))::int]); end loop;
  foreach v_line slice 1 in array v_paylines loop
    v_symbol:=v_grid[v_line[1]]; v_match:=v_grid[v_line[2]]=v_symbol and v_grid[v_line[3]]=v_symbol;
    if v_match then
      v_line_payout:=case v_symbol when 'diamond' then p_wager*50 when 'crown' then p_wager*30 when 'watermelon' then p_wager*20 when 'grape' then p_wager*10 when 'cherry' then p_wager*5 else p_wager*3 end;
      v_payout:=v_payout+v_line_payout;
    end if;
  end loop;
  insert into public.saki_slot_spins(room_id,user_id,wager,symbols,payout) values(p_room_id,auth.uid(),p_wager,to_jsonb(v_grid),v_payout) returning id into v_id;
  if v_payout>0 then update public.saki_account_modules set gold_coins=gold_coins+v_payout,updated_at=now() where user_id=auth.uid(); end if;
  select gold_coins into v_balance from public.saki_account_modules where user_id=auth.uid();
  return query select v_id,to_jsonb(v_grid),v_payout,coalesce(v_balance,0);
end; $$;
revoke all on function public.saki_vip_slot_spin(uuid,bigint) from public;
grant execute on function public.saki_vip_slot_spin(uuid,bigint) to authenticated;
