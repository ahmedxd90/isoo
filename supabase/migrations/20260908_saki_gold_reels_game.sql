create table if not exists public.saki_gold_reel_spins (
  id bigint generated always as identity primary key,
  room_id uuid not null references public.rooms(id) on delete cascade,
  user_id uuid not null references public.profiles(id) on delete cascade,
  wager bigint not null check (wager > 0),
  symbols jsonb not null,
  payout bigint not null default 0,
  created_at timestamptz not null default now()
);

alter table public.saki_gold_reel_spins enable row level security;
drop policy if exists saki_gold_reel_spins_self on public.saki_gold_reel_spins;
create policy saki_gold_reel_spins_self on public.saki_gold_reel_spins for select to authenticated using (user_id = auth.uid());
create index if not exists saki_gold_reel_spins_user_created_idx on public.saki_gold_reel_spins(user_id, created_at desc);

create or replace function public.saki_gold_reels_spin(p_room_id uuid, p_wager bigint)
returns table(spin_id bigint, symbols jsonb, payout bigint, gold_coins bigint)
language plpgsql security definer set search_path = public
as $$
declare
  v_symbols text[] := array['diamond','ruby','sapphire','crown','chest','coin'];
  v_grid text[] := array[]::text[];
  v_symbol text;
  v_count integer;
  v_payout bigint := 0;
  v_balance bigint;
  v_id bigint;
  i integer;
  j integer;
begin
  if p_room_id is null or not exists(select 1 from public.rooms r where r.id = p_room_id and r.is_active = true) then raise exception 'game_room_not_available'; end if;
  if p_wager not in (10,50,100,500,1000,5000,10000) then raise exception 'invalid_reels_wager'; end if;
  update public.saki_account_modules m set gold_coins = m.gold_coins - p_wager, updated_at = now() where m.user_id = auth.uid() and m.gold_coins >= p_wager;
  if not found then raise exception 'insufficient_gold'; end if;
  for i in 1..15 loop v_grid := array_append(v_grid, v_symbols[1 + floor(random() * array_length(v_symbols, 1))::int]); end loop;
  foreach v_symbol in array v_symbols loop
    select count(*) into v_count from unnest(v_grid) as x where x = v_symbol;
    if v_count >= 5 then v_payout := greatest(v_payout, p_wager * 25);
    elsif v_count >= 4 then v_payout := greatest(v_payout, p_wager * 8);
    elsif v_count >= 3 then v_payout := greatest(v_payout, p_wager * 2);
    end if;
  end loop;
  if v_grid[1] = 'chest' and v_grid[5] = 'chest' and v_grid[9] = 'chest' then v_payout := v_payout + p_wager * 10; end if;
  insert into public.saki_gold_reel_spins(room_id,user_id,wager,symbols,payout) values(p_room_id,auth.uid(),p_wager,to_jsonb(v_grid),v_payout) returning id into v_id;
  if v_payout > 0 then
    update public.saki_account_modules m set gold_coins = m.gold_coins + v_payout, updated_at = now() where m.user_id = auth.uid();
  end if;
  select m.gold_coins into v_balance from public.saki_account_modules m where m.user_id = auth.uid();
  return query select v_id, to_jsonb(v_grid), v_payout, coalesce(v_balance,0);
end;
$$;
revoke all on function public.saki_gold_reels_spin(uuid,bigint) from public;
grant execute on function public.saki_gold_reels_spin(uuid,bigint) to authenticated;
