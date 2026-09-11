-- Keep a real, replayable history while preventing unauthorized or duplicate game actions.

create or replace function public.saki_buffet_place_bet(
  p_room_id uuid,
  p_round_id bigint,
  p_food_id smallint,
  p_amount bigint
)
returns table(bet_id bigint, balance bigint, food_total bigint)
language plpgsql
security definer
set search_path = public
as $$
declare
  v_round public.saki_buffet_rounds;
  v_balance bigint;
  v_count integer;
  v_bet_id bigint;
  v_total bigint;
begin
  if auth.uid() is null then raise exception 'not_authenticated'; end if;
  if not exists (
    select 1 from public.room_members
    where room_id = p_room_id and user_id = auth.uid()
  ) and not exists (
    select 1 from public.rooms
    where id = p_room_id and owner_id = auth.uid()
  ) then
    raise exception 'not_room_member';
  end if;

  select * into v_round
  from public.saki_buffet_rounds
  where id = p_round_id and room_id = p_room_id
  for update;

  if v_round.id is null then raise exception 'round_not_found'; end if;
  if v_round.status <> 'open' or v_round.betting_ends_at <= now() then
    raise exception 'betting_closed';
  end if;
  if p_food_id not between 1 and 8 then raise exception 'invalid_food'; end if;
  if p_amount not in (100, 1000, 10000, 100000) then
    raise exception 'invalid_bet';
  end if;

  select count(distinct food_id) into v_count
  from public.saki_buffet_bets
  where round_id = p_round_id and user_id = auth.uid();
  if not exists (
    select 1 from public.saki_buffet_bets
    where round_id = p_round_id and user_id = auth.uid() and food_id = p_food_id
  ) and v_count >= 6 then
    raise exception 'max_six_foods';
  end if;

  update public.saki_account_modules
  set gold_coins = gold_coins - p_amount, updated_at = now()
  where user_id = auth.uid() and gold_coins >= p_amount
  returning gold_coins into v_balance;
  if not found then raise exception 'insufficient_gold'; end if;

  insert into public.saki_buffet_bets(round_id, room_id, user_id, food_id, amount)
  values (p_round_id, p_room_id, auth.uid(), p_food_id, p_amount)
  returning id into v_bet_id;

  select coalesce(sum(amount), 0) into v_total
  from public.saki_buffet_bets
  where round_id = p_round_id and user_id = auth.uid() and food_id = p_food_id;

  return query select v_bet_id, v_balance, v_total;
end;
$$;

create or replace function public.saki_buffet_finish_round(
  p_room_id uuid,
  p_round_id bigint
)
returns public.saki_buffet_rounds
language plpgsql
security definer
set search_path = public
as $$
declare
  v_round public.saki_buffet_rounds;
  v_bet record;
  v_multiplier bigint;
  v_payout bigint;
begin
  if auth.uid() is null then raise exception 'not_authenticated'; end if;
  if not exists (
    select 1 from public.room_members
    where room_id = p_room_id and user_id = auth.uid()
  ) and not exists (
    select 1 from public.rooms
    where id = p_room_id and owner_id = auth.uid()
  ) then
    raise exception 'not_room_member';
  end if;

  select * into v_round
  from public.saki_buffet_rounds
  where id = p_round_id and room_id = p_room_id
  for update;
  if v_round.id is null then raise exception 'round_not_found'; end if;
  if v_round.status = 'finished' then return v_round; end if;
  if v_round.status <> 'spinning' then raise exception 'round_not_spinning'; end if;
  if v_round.spinning_started_at > now() - interval '5 seconds' then
    raise exception 'result_not_ready';
  end if;

  v_multiplier := case v_round.winner_food_id
    when 1 then 10 when 2 then 15 when 3 then 25 when 4 then 45 else 5 end;
  update public.saki_buffet_rounds
  set status = 'finished', result_shown_at = now(), resolved_at = now()
  where id = p_round_id
  returning * into v_round;

  for v_bet in
    select * from public.saki_buffet_bets
    where round_id = p_round_id and payout = 0
    for update
  loop
    v_payout := case
      when v_bet.food_id = v_round.winner_food_id
      then v_bet.amount * v_multiplier else 0 end;
    update public.saki_buffet_bets set payout = v_payout where id = v_bet.id;
    if v_payout > 0 then
      update public.saki_account_modules
      set gold_coins = gold_coins + v_payout, updated_at = now()
      where user_id = v_bet.user_id;
    end if;
  end loop;
  return v_round;
end;
$$;

-- Keep the latest ten completed rounds per room; do not erase the live history.
create or replace function public.saki_buffet_cleanup_finished()
returns integer
language plpgsql
security definer
set search_path = public
as $$
declare v_deleted integer;
begin
  delete from public.saki_buffet_rounds r
  where r.status = 'finished'
    and r.id not in (
      select recent.id
      from public.saki_buffet_rounds recent
      where recent.room_id = r.room_id and recent.status = 'finished'
      order by recent.id desc
      limit 10
    );
  get diagnostics v_deleted = row_count;
  return v_deleted;
end;
$$;

revoke all on function public.saki_buffet_place_bet(uuid,bigint,smallint,bigint) from public;
revoke all on function public.saki_buffet_finish_round(uuid,bigint) from public;
revoke all on function public.saki_buffet_cleanup_finished() from public;
grant execute on function public.saki_buffet_place_bet(uuid,bigint,smallint,bigint) to authenticated;
grant execute on function public.saki_buffet_finish_round(uuid,bigint) to authenticated;
grant execute on function public.saki_buffet_cleanup_finished() to service_role;

-- Make sure realtime continues delivering round and bet changes after migrations.
do $$ begin
  if not exists (
    select 1 from pg_publication_tables
    where pubname = 'supabase_realtime'
      and schemaname = 'public'
      and tablename = 'saki_buffet_rounds'
  ) then
    alter publication supabase_realtime add table public.saki_buffet_rounds;
  end if;
  if not exists (
    select 1 from pg_publication_tables
    where pubname = 'supabase_realtime'
      and schemaname = 'public'
      and tablename = 'saki_buffet_bets'
  ) then
    alter publication supabase_realtime add table public.saki_buffet_bets;
  end if;
end $$;
