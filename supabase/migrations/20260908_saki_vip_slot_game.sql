create table if not exists public.saki_slot_spins (
  id bigint generated always as identity primary key,
  room_id uuid not null references public.rooms(id) on delete cascade,
  user_id uuid not null references public.profiles(id) on delete cascade,
  wager bigint not null check (wager > 0),
  symbols jsonb not null,
  payout bigint not null default 0 check (payout >= 0),
  created_at timestamptz not null default now()
);

alter table public.saki_slot_spins enable row level security;
drop policy if exists saki_slot_spins_self on public.saki_slot_spins;
create policy saki_slot_spins_self on public.saki_slot_spins for select to authenticated using (user_id = auth.uid());
create index if not exists saki_slot_spins_user_created_idx on public.saki_slot_spins(user_id, created_at desc);

create or replace function public.saki_vip_slot_spin(p_room_id uuid, p_wager bigint)
returns table(spin_id bigint, symbols jsonb, payout bigint, gold_coins bigint)
language plpgsql security definer set search_path = public
as $$
declare
  v_symbols text[] := array['diamond','crown','watermelon','grape','cherry','mango'];
  v_grid text[] := array[]::text[];
  v_paylines int[][] := array[array[1,2,3],array[4,5,6],array[7,8,9],array[1,5,9],array[7,5,3]];
  v_line int[]; v_symbol text; v_payout bigint := 0; v_line_payout bigint; v_balance bigint; v_id bigint; v_match boolean; i integer;
begin
  if auth.uid() is null then raise exception 'not_authenticated'; end if;
  if p_room_id is null or not exists(select 1 from public.rooms r where r.id=p_room_id and r.is_active=true) then raise exception 'game_room_not_available'; end if;
  if p_wager not in (10,50,100,500,1000,5000,10000) then raise exception 'invalid_slot_wager'; end if;
  update public.saki_account_modules set gold_coins=gold_coins-p_wager,updated_at=now() where user_id=auth.uid() and gold_coins>=p_wager;
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
