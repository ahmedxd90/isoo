create table if not exists public.saki_buffet_rounds (
  id bigint generated always as identity primary key,
  room_id uuid not null references public.rooms(id) on delete cascade,
  round_number bigint not null,
  status text not null default 'open' check (status in ('open','spinning','finished')),
  started_at timestamptz not null default now(),
  betting_ends_at timestamptz not null,
  winner_food_id smallint,
  resolved_at timestamptz,
  created_at timestamptz not null default now(),
  unique(room_id, round_number)
);

create table if not exists public.saki_buffet_bets (
  id bigint generated always as identity primary key,
  round_id bigint not null references public.saki_buffet_rounds(id) on delete cascade,
  room_id uuid not null references public.rooms(id) on delete cascade,
  user_id uuid not null references public.profiles(id) on delete cascade,
  food_id smallint not null check (food_id between 1 and 8),
  amount bigint not null check (amount > 0),
  payout bigint not null default 0 check (payout >= 0),
  created_at timestamptz not null default now()
);

create index if not exists saki_buffet_rounds_room_status_idx on public.saki_buffet_rounds(room_id,status,betting_ends_at desc);
create index if not exists saki_buffet_bets_round_food_idx on public.saki_buffet_bets(round_id,food_id);
create index if not exists saki_buffet_bets_user_created_idx on public.saki_buffet_bets(user_id,created_at desc);

alter table public.saki_buffet_rounds enable row level security;
alter table public.saki_buffet_bets enable row level security;
drop policy if exists saki_buffet_rounds_read on public.saki_buffet_rounds;
create policy saki_buffet_rounds_read on public.saki_buffet_rounds for select to authenticated using (exists(select 1 from public.room_members m where m.room_id=saki_buffet_rounds.room_id and m.user_id=auth.uid()));
drop policy if exists saki_buffet_bets_read on public.saki_buffet_bets;
create policy saki_buffet_bets_read on public.saki_buffet_bets for select to authenticated using (exists(select 1 from public.room_members m where m.room_id=saki_buffet_bets.room_id and m.user_id=auth.uid()));

do $$ begin
  if not exists (select 1 from pg_publication_tables where pubname='supabase_realtime' and schemaname='public' and tablename='saki_buffet_rounds') then
    alter publication supabase_realtime add table public.saki_buffet_rounds;
  end if;
end $$;

do $$ begin
  if not exists (select 1 from pg_publication_tables where pubname='supabase_realtime' and schemaname='public' and tablename='saki_buffet_bets') then
    alter publication supabase_realtime add table public.saki_buffet_bets;
  end if;
end $$;

create or replace function public.saki_buffet_get_round(p_room_id uuid)
returns public.saki_buffet_rounds
language plpgsql security definer set search_path=public
as $$
declare v_round public.saki_buffet_rounds;
begin
  if auth.uid() is null then raise exception 'not_authenticated'; end if;
  if not exists(select 1 from public.room_members where room_id=p_room_id and user_id=auth.uid()) then raise exception 'not_room_member'; end if;
  select * into v_round from public.saki_buffet_rounds where room_id=p_room_id and status in ('open','spinning') and betting_ends_at > now() - interval '5 seconds' order by id desc limit 1;
  if v_round.id is null or v_round.status='finished' or v_round.betting_ends_at <= now() then
    insert into public.saki_buffet_rounds(room_id,round_number,betting_ends_at) values(p_room_id,coalesce((select max(round_number)+1 from public.saki_buffet_rounds where room_id=p_room_id),1),now()+interval '30 seconds') returning * into v_round;
  end if;
  return v_round;
end; $$;

create or replace function public.saki_buffet_place_bet(p_room_id uuid,p_round_id bigint,p_food_id smallint,p_amount bigint)
returns table(bet_id bigint, balance bigint, food_total bigint)
language plpgsql security definer set search_path=public
as $$
declare v_round public.saki_buffet_rounds; v_balance bigint; v_count int; v_bet_id bigint; v_total bigint;
begin
  if auth.uid() is null then raise exception 'not_authenticated'; end if;
  select * into v_round from public.saki_buffet_rounds where id=p_round_id and room_id=p_room_id for update;
  if v_round.id is null then raise exception 'round_not_found'; end if;
  if v_round.status <> 'open' or v_round.betting_ends_at <= now() then raise exception 'betting_closed'; end if;
  if p_food_id not between 1 and 8 then raise exception 'invalid_food'; end if;
  if p_amount not in (100,1000,10000,100000) then raise exception 'invalid_bet'; end if;
  select count(distinct food_id) into v_count from public.saki_buffet_bets where round_id=p_round_id and user_id=auth.uid();
  if not exists(select 1 from public.saki_buffet_bets where round_id=p_round_id and user_id=auth.uid() and food_id=p_food_id) and v_count >= 6 then raise exception 'max_six_foods'; end if;
  update public.saki_account_modules set gold_coins=gold_coins-p_amount,updated_at=now() where user_id=auth.uid() and gold_coins>=p_amount returning gold_coins into v_balance;
  if not found then raise exception 'insufficient_gold'; end if;
  insert into public.saki_buffet_bets(round_id,room_id,user_id,food_id,amount) values(p_round_id,p_room_id,auth.uid(),p_food_id,p_amount) returning id into v_bet_id;
  select coalesce(sum(amount),0) into v_total from public.saki_buffet_bets where round_id=p_round_id and user_id=auth.uid() and food_id=p_food_id;
  return query select v_bet_id,v_balance,v_total;
end; $$;

create or replace function public.saki_buffet_resolve_round(p_room_id uuid,p_round_id bigint)
returns public.saki_buffet_rounds
language plpgsql security definer set search_path=public
as $$
declare v_round public.saki_buffet_rounds; v_food smallint; v_multiplier bigint; v_bet record; v_payout bigint;
begin
  select * into v_round from public.saki_buffet_rounds where id=p_round_id and room_id=p_room_id for update;
  if v_round.id is null then raise exception 'round_not_found'; end if;
  if v_round.status='finished' then return v_round; end if;
  if v_round.betting_ends_at > now() then raise exception 'round_not_ready'; end if;
  v_food := 1 + floor(random()*8)::int;
  v_multiplier := case v_food when 1 then 10 when 2 then 15 when 3 then 25 when 4 then 45 else 5 end;
  update public.saki_buffet_rounds set status='finished',winner_food_id=v_food,resolved_at=now() where id=p_round_id returning * into v_round;
  for v_bet in select * from public.saki_buffet_bets where round_id=p_round_id loop
    v_payout := case when v_bet.food_id=v_food then v_bet.amount*v_multiplier else 0 end;
    update public.saki_buffet_bets set payout=v_payout where id=v_bet.id;
    if v_payout>0 then update public.saki_account_modules set gold_coins=gold_coins+v_payout,updated_at=now() where user_id=v_bet.user_id; end if;
  end loop;
  return v_round;
end; $$;

revoke all on function public.saki_buffet_get_round(uuid) from public;
revoke all on function public.saki_buffet_place_bet(uuid,bigint,smallint,bigint) from public;
revoke all on function public.saki_buffet_resolve_round(uuid,bigint) from public;
grant execute on function public.saki_buffet_get_round(uuid) to authenticated;
grant execute on function public.saki_buffet_place_bet(uuid,bigint,smallint,bigint) to authenticated;
grant execute on function public.saki_buffet_resolve_round(uuid,bigint) to authenticated;
