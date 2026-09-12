create table if not exists public.saki_lion_party_rounds (
  id bigint generated always as identity primary key,
  room_id uuid not null references public.rooms(id) on delete cascade,
  round_number bigint not null,
  status text not null default 'open' check (status in ('open','spinning','finished')),
  started_at timestamptz not null default now(),
  betting_ends_at timestamptz not null,
  spinning_started_at timestamptz,
  winner_item_id smallint,
  resolved_at timestamptz,
  result_shown_at timestamptz,
  created_at timestamptz not null default now(),
  unique(room_id, round_number)
);

create table if not exists public.saki_lion_party_bets (
  id bigint generated always as identity primary key,
  round_id bigint not null references public.saki_lion_party_rounds(id) on delete cascade,
  room_id uuid not null references public.rooms(id) on delete cascade,
  user_id uuid not null references public.profiles(id) on delete cascade,
  item_id smallint not null check (item_id between 1 and 8),
  amount bigint not null check (amount in (1000,10000,100000,1000000)),
  payout bigint not null default 0 check (payout >= 0),
  created_at timestamptz not null default now()
);

create index if not exists saki_lion_rounds_room_status_idx on public.saki_lion_party_rounds(room_id,status,betting_ends_at desc);
create index if not exists saki_lion_bets_round_item_idx on public.saki_lion_party_bets(round_id,item_id);
create index if not exists saki_lion_bets_user_created_idx on public.saki_lion_party_bets(user_id,created_at desc);
create unique index if not exists saki_lion_bets_once_per_item_idx on public.saki_lion_party_bets(round_id,user_id,item_id);

alter table public.saki_lion_party_rounds enable row level security;
alter table public.saki_lion_party_bets enable row level security;
drop policy if exists saki_lion_rounds_read on public.saki_lion_party_rounds;
create policy saki_lion_rounds_read on public.saki_lion_party_rounds for select to authenticated using (exists(select 1 from public.room_members m where m.room_id=saki_lion_party_rounds.room_id and m.user_id=auth.uid()));
drop policy if exists saki_lion_bets_read on public.saki_lion_party_bets;
create policy saki_lion_bets_read on public.saki_lion_party_bets for select to authenticated using (exists(select 1 from public.room_members m where m.room_id=saki_lion_party_bets.room_id and m.user_id=auth.uid()));

do $$ begin
  if not exists (select 1 from pg_publication_tables where pubname='supabase_realtime' and schemaname='public' and tablename='saki_lion_party_rounds') then alter publication supabase_realtime add table public.saki_lion_party_rounds; end if;
  if not exists (select 1 from pg_publication_tables where pubname='supabase_realtime' and schemaname='public' and tablename='saki_lion_party_bets') then alter publication supabase_realtime add table public.saki_lion_party_bets; end if;
end $$;

create or replace function public.saki_lion_party_get_round(p_room_id uuid)
returns public.saki_lion_party_rounds language plpgsql security definer set search_path=public as $$
declare v_round public.saki_lion_party_rounds;
begin
  if auth.uid() is null then raise exception 'not_authenticated'; end if;
  if not exists(select 1 from public.room_members where room_id=p_room_id and user_id=auth.uid()) then raise exception 'not_room_member'; end if;
  select * into v_round from public.saki_lion_party_rounds where room_id=p_room_id and status in ('open','spinning') order by id desc limit 1 for update;
  if v_round.id is null then
    insert into public.saki_lion_party_rounds(room_id,round_number,betting_ends_at)
    values(p_room_id,coalesce((select max(round_number)+1 from public.saki_lion_party_rounds where room_id=p_room_id),1),now()+interval '30 seconds') returning * into v_round;
  end if;
  return v_round;
end; $$;

create or replace function public.saki_lion_party_place_bet(p_room_id uuid,p_round_id bigint,p_item_id smallint,p_amount bigint)
returns table(bet_id bigint,balance bigint,item_total bigint) language plpgsql security definer set search_path=public as $$
declare v_round public.saki_lion_party_rounds; v_balance bigint; v_bet_id bigint; v_total bigint;
begin
  if auth.uid() is null then raise exception 'not_authenticated'; end if;
  if p_item_id not between 1 and 8 then raise exception 'invalid_item'; end if;
  if p_amount not in (1000,10000,100000,1000000) then raise exception 'invalid_bet'; end if;
  select * into v_round from public.saki_lion_party_rounds where id=p_round_id and room_id=p_room_id for update;
  if v_round.id is null then raise exception 'round_not_found'; end if;
  if v_round.status <> 'open' or v_round.betting_ends_at <= now() then raise exception 'betting_closed'; end if;
  update public.saki_account_modules set gold_coins=gold_coins-p_amount,updated_at=now() where user_id=auth.uid() and gold_coins>=p_amount returning gold_coins into v_balance;
  if not found then raise exception 'insufficient_gold'; end if;
  begin
    insert into public.saki_lion_party_bets(round_id,room_id,user_id,item_id,amount) values(p_round_id,p_room_id,auth.uid(),p_item_id,p_amount) returning id into v_bet_id;
  exception when unique_violation then
    update public.saki_account_modules set gold_coins=gold_coins+p_amount,updated_at=now() where user_id=auth.uid();
    raise exception 'duplicate_item_bet';
  end;
  select coalesce(sum(amount),0) into v_total from public.saki_lion_party_bets where round_id=p_round_id and user_id=auth.uid() and item_id=p_item_id;
  return query select v_bet_id,v_balance,v_total;
end; $$;

create or replace function public.saki_lion_party_resolve_round(p_room_id uuid,p_round_id bigint)
returns public.saki_lion_party_rounds language plpgsql security definer set search_path=public as $$
declare v_round public.saki_lion_party_rounds; v_item smallint; v_multiplier bigint; v_bet record; v_payout bigint;
begin
  select * into v_round from public.saki_lion_party_rounds where id=p_round_id and room_id=p_room_id for update;
  if v_round.id is null then raise exception 'round_not_found'; end if;
  if v_round.status='finished' then return v_round; end if;
  if v_round.betting_ends_at > now() then raise exception 'round_not_ready'; end if;
  if v_round.status='open' then
    v_item := 1 + floor(random()*8)::int;
    update public.saki_lion_party_rounds set status='spinning',winner_item_id=v_item,spinning_started_at=now() where id=p_round_id returning * into v_round;
    return v_round;
  end if;
  if v_round.spinning_started_at > now()-interval '5 seconds' then return v_round; end if;
  v_item := v_round.winner_item_id;
  v_multiplier := case v_item when 1 then 10 when 2 then 15 when 3 then 25 when 4 then 45 else 5 end;
  update public.saki_lion_party_rounds set status='finished',resolved_at=now(),result_shown_at=now() where id=p_round_id returning * into v_round;
  for v_bet in select * from public.saki_lion_party_bets where round_id=p_round_id loop
    v_payout := case when v_bet.item_id=v_item then v_bet.amount*v_multiplier else 0 end;
    update public.saki_lion_party_bets set payout=v_payout where id=v_bet.id;
    if v_payout>0 then update public.saki_account_modules set gold_coins=gold_coins+v_payout,updated_at=now() where user_id=v_bet.user_id; end if;
  end loop;
  return v_round;
end; $$;

create or replace function public.saki_lion_party_server_tick() returns integer language plpgsql security definer set search_path=public as $$
declare r record; v_round public.saki_lion_party_rounds; v_count integer:=0;
begin
  for r in select id from public.rooms where coalesce(is_active,true)=true loop
    select * into v_round from public.saki_lion_party_rounds where room_id=r.id and status in ('open','spinning') order by id desc limit 1 for update;
    if v_round.id is null then insert into public.saki_lion_party_rounds(room_id,round_number,betting_ends_at) values(r.id,coalesce((select max(round_number)+1 from public.saki_lion_party_rounds where room_id=r.id),1),now()+interval '30 seconds'); v_count:=v_count+1;
    elsif v_round.status='open' and v_round.betting_ends_at<=now() then perform public.saki_lion_party_resolve_round(r.id,v_round.id); v_count:=v_count+1;
    elsif v_round.status='spinning' and v_round.spinning_started_at<=now()-interval '5 seconds' then perform public.saki_lion_party_resolve_round(r.id,v_round.id); insert into public.saki_lion_party_rounds(room_id,round_number,betting_ends_at) values(r.id,v_round.round_number+1,now()+interval '30 seconds'); v_count:=v_count+1;
    end if;
  end loop;
  return v_count;
end; $$;

revoke all on function public.saki_lion_party_get_round(uuid) from public;
revoke all on function public.saki_lion_party_place_bet(uuid,bigint,smallint,bigint) from public;
revoke all on function public.saki_lion_party_resolve_round(uuid,bigint) from public;
revoke all on function public.saki_lion_party_server_tick() from public;
grant execute on function public.saki_lion_party_get_round(uuid) to authenticated;
grant execute on function public.saki_lion_party_place_bet(uuid,bigint,smallint,bigint) to authenticated;
grant execute on function public.saki_lion_party_resolve_round(uuid,bigint) to authenticated;
grant execute on function public.saki_lion_party_server_tick() to service_role;

do $scheduler$ begin
  if not exists(select 1 from cron.job where jobname='saki-lion-party-global-tick') then perform cron.schedule('saki-lion-party-global-tick','5 seconds',$job$select public.saki_lion_party_server_tick();$job$); end if;
exception when undefined_table or undefined_function then null;
end $scheduler$;
