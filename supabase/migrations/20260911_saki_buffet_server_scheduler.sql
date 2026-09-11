create or replace function public.saki_buffet_get_round(p_room_id uuid)
returns public.saki_buffet_rounds
language plpgsql security definer set search_path=public
as $$
declare v_round public.saki_buffet_rounds;
begin
  if auth.uid() is null then raise exception 'not_authenticated'; end if;
  if not exists(select 1 from public.room_members where room_id=p_room_id and user_id=auth.uid()) then raise exception 'not_room_member'; end if;
  select * into v_round from public.saki_buffet_rounds
    where room_id=p_room_id and status in ('open','spinning')
    order by id desc limit 1;
  if v_round.id is null then
    insert into public.saki_buffet_rounds(room_id,round_number,betting_ends_at)
    values(p_room_id,coalesce((select max(round_number)+1 from public.saki_buffet_rounds where room_id=p_room_id),1),now()+interval '30 seconds')
    returning * into v_round;
  end if;
  return v_round;
end; $$;

create or replace function public.saki_buffet_server_tick()
returns integer
language plpgsql security definer set search_path=public
as $$
declare r record; v_round public.saki_buffet_rounds; v_food smallint; v_multiplier bigint; v_bet record; v_payout bigint; v_count integer:=0;
begin
  for r in select id from public.rooms where coalesce(is_active,true)=true loop
    select * into v_round from public.saki_buffet_rounds where room_id=r.id and status in ('open','spinning') order by id desc limit 1 for update;
    if v_round.id is null then
      insert into public.saki_buffet_rounds(room_id,round_number,betting_ends_at)
      values(r.id,coalesce((select max(round_number)+1 from public.saki_buffet_rounds where room_id=r.id),1),now()+interval '30 seconds');
      v_count:=v_count+1;
    elsif v_round.status='open' and v_round.betting_ends_at<=now() then
      v_food:=1+floor(random()*8)::int;
      update public.saki_buffet_rounds set status='spinning',winner_food_id=v_food,spinning_started_at=now() where id=v_round.id;
      v_count:=v_count+1;
    elsif v_round.status='spinning' and v_round.spinning_started_at<=now()-interval '5 seconds' then
      v_multiplier:=case v_round.winner_food_id when 1 then 10 when 2 then 15 when 3 then 25 when 4 then 45 else 5 end;
      update public.saki_buffet_rounds set status='finished',result_shown_at=now() where id=v_round.id;
      for v_bet in select * from public.saki_buffet_bets where round_id=v_round.id loop
        v_payout:=case when v_bet.food_id=v_round.winner_food_id then v_bet.amount*v_multiplier else 0 end;
        update public.saki_buffet_bets set payout=v_payout where id=v_bet.id;
        if v_payout>0 then update public.saki_account_modules set gold_coins=gold_coins+v_payout,updated_at=now() where user_id=v_bet.user_id; end if;
      end loop;
      insert into public.saki_buffet_rounds(room_id,round_number,betting_ends_at)
      values(v_round.room_id,v_round.round_number+1,now()+interval '30 seconds');
      v_count:=v_count+1;
    end if;
  end loop;
  return v_count;
end; $$;
revoke all on function public.saki_buffet_server_tick() from public;
grant execute on function public.saki_buffet_server_tick() to service_role;

-- A single database scheduler keeps every active room moving without an app session.
do $scheduler$ begin
  if not exists(select 1 from cron.job where jobname='saki-buffet-global-tick') then
    perform cron.schedule('saki-buffet-global-tick','30 seconds',$job$select public.saki_buffet_server_tick();$job$);
  end if;
end $scheduler$;
