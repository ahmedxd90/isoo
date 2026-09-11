alter table public.saki_buffet_rounds add column if not exists spinning_started_at timestamptz;
alter table public.saki_buffet_rounds add column if not exists result_shown_at timestamptz;

drop function if exists public.saki_buffet_resolve_round(uuid,bigint);
create or replace function public.saki_buffet_resolve_round(p_room_id uuid,p_round_id bigint)
returns public.saki_buffet_rounds
language plpgsql security definer set search_path=public
as $$
declare v_round public.saki_buffet_rounds; v_food smallint;
begin
  if auth.uid() is null then raise exception 'not_authenticated'; end if;
  if not exists(select 1 from public.room_members where room_id=p_room_id and user_id=auth.uid()) then raise exception 'not_room_member'; end if;
  select * into v_round from public.saki_buffet_rounds where id=p_round_id and room_id=p_room_id for update;
  if v_round.id is null then raise exception 'round_not_found'; end if;
  if v_round.status='finished' then return v_round; end if;
  if v_round.status='spinning' then return v_round; end if;
  if v_round.betting_ends_at>now() then raise exception 'round_not_ready'; end if;
  v_food:=1+floor(random()*8)::int;
  update public.saki_buffet_rounds set status='spinning',winner_food_id=v_food,spinning_started_at=now() where id=p_round_id returning * into v_round;
  return v_round;
end; $$;

drop function if exists public.saki_buffet_finish_round(uuid,bigint);
create or replace function public.saki_buffet_finish_round(p_room_id uuid,p_round_id bigint)
returns public.saki_buffet_rounds
language plpgsql security definer set search_path=public
as $$
declare v_round public.saki_buffet_rounds; v_bet record; v_multiplier bigint; v_payout bigint;
begin
  if auth.uid() is null then raise exception 'not_authenticated'; end if;
  select * into v_round from public.saki_buffet_rounds where id=p_round_id and room_id=p_room_id for update;
  if v_round.id is null then raise exception 'round_not_found'; end if;
  if v_round.status='finished' then return v_round; end if;
  if v_round.status<>'spinning' then raise exception 'round_not_spinning'; end if;
  if v_round.spinning_started_at>now()-interval '5 seconds' then raise exception 'result_not_ready'; end if;
  v_multiplier:=case v_round.winner_food_id when 1 then 10 when 2 then 15 when 3 then 25 when 4 then 45 else 5 end;
  update public.saki_buffet_rounds set status='finished',result_shown_at=now() where id=p_round_id returning * into v_round;
  for v_bet in select * from public.saki_buffet_bets where round_id=p_round_id loop
    v_payout:=case when v_bet.food_id=v_round.winner_food_id then v_bet.amount*v_multiplier else 0 end;
    update public.saki_buffet_bets set payout=v_payout where id=v_bet.id;
    if v_payout>0 then
      update public.saki_account_modules set gold_coins=gold_coins+v_payout,updated_at=now() where user_id=v_bet.user_id;
    end if;
  end loop;
  return v_round;
end; $$;

create or replace function public.saki_buffet_round_leaderboard(p_round_id bigint)
returns table(user_id uuid,username text,avatar_url text,profit bigint)
language sql security definer set search_path=public
as $$
  select b.user_id,p.username,p.avatar_url,sum(b.payout)::bigint as profit
  from public.saki_buffet_bets b
  join public.profiles p on p.id=b.user_id
  where b.round_id=p_round_id and b.payout>0
  group by b.user_id,p.username,p.avatar_url
  order by profit desc, b.user_id
  limit 3;
$$;

revoke all on function public.saki_buffet_resolve_round(uuid,bigint) from public;
revoke all on function public.saki_buffet_finish_round(uuid,bigint) from public;
revoke all on function public.saki_buffet_round_leaderboard(bigint) from public;
grant execute on function public.saki_buffet_resolve_round(uuid,bigint) to authenticated;
grant execute on function public.saki_buffet_finish_round(uuid,bigint) to authenticated;
grant execute on function public.saki_buffet_round_leaderboard(bigint) to authenticated;
