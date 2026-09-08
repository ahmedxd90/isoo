create table if not exists public.room_luck_bags (
  id uuid primary key default gen_random_uuid(),
  room_id uuid not null references public.rooms(id) on delete cascade,
  sender_id uuid not null references public.profiles(id) on delete cascade,
  total_gold bigint not null check (total_gold in (1000,10000,100000,1000000)),
  recipient_limit integer not null check (recipient_limit in (5,10,20,50,100)),
  claimed_count integer not null default 0 check (claimed_count >= 0 and claimed_count <= recipient_limit),
  remaining_gold bigint not null,
  status text not null default 'open' check (status in ('open','closed','empty')),
  created_at timestamptz not null default now(),
  expires_at timestamptz not null default (now() + interval '2 minutes')
);
create table if not exists public.room_luck_bag_claims (
  id uuid primary key default gen_random_uuid(),
  bag_id uuid not null references public.room_luck_bags(id) on delete cascade,
  user_id uuid not null references public.profiles(id) on delete cascade,
  amount_gold bigint not null check (amount_gold > 0),
  claimed_at timestamptz not null default now(),
  unique(bag_id,user_id)
);
alter table public.room_luck_bags enable row level security;
alter table public.room_luck_bag_claims enable row level security;
drop policy if exists room_luck_bags_read on public.room_luck_bags;
create policy room_luck_bags_read on public.room_luck_bags for select to authenticated using (true);
drop policy if exists room_luck_claims_read on public.room_luck_bag_claims;
create policy room_luck_claims_read on public.room_luck_bag_claims for select to authenticated using (true);

create or replace function public.create_room_luck_bag(p_room_id uuid,p_total_gold bigint,p_recipient_limit integer)
returns public.room_luck_bags language plpgsql security definer set search_path=public as $$
declare b public.room_luck_bags;
begin
 if not exists(select 1 from room_members where room_id=p_room_id and user_id=auth.uid()) then raise exception 'not_room_member'; end if;
 if p_total_gold not in (1000,10000,100000,1000000) or p_recipient_limit not in (5,10,20,50,100) then raise exception 'invalid_luck_bag_options'; end if;
 update saki_account_modules set gold_coins=gold_coins-p_total_gold,updated_at=now() where user_id=auth.uid() and gold_coins>=p_total_gold;
 if not found then raise exception 'insufficient_gold'; end if;
 insert into room_luck_bags(room_id,sender_id,total_gold,recipient_limit,remaining_gold) values(p_room_id,auth.uid(),p_total_gold,p_recipient_limit,p_total_gold) returning * into b;
 return b;
end; $$;

create or replace function public.claim_room_luck_bag(p_bag_id uuid)
returns table(bag_id uuid,amount_gold bigint,claimed_count integer,remaining_gold bigint,status text)
language plpgsql security definer set search_path=public as $$
declare b public.room_luck_bags; amount bigint; left_slots integer;
begin
 select * into b from room_luck_bags where id=p_bag_id for update;
 if b.id is null then raise exception 'luck_bag_not_found'; end if;
 if not exists(select 1 from room_members where room_id=b.room_id and user_id=auth.uid()) then raise exception 'not_room_member'; end if;
 if b.expires_at<=now() or b.status<>'open' then raise exception 'luck_bag_closed'; end if;
 if exists(select 1 from room_luck_bag_claims where bag_id=b.id and user_id=auth.uid()) then raise exception 'luck_bag_already_claimed'; end if;
 left_slots:=b.recipient_limit-b.claimed_count;
 if left_slots<=0 or b.remaining_gold<=0 then raise exception 'luck_bag_empty'; end if;
 if left_slots=1 then amount:=b.remaining_gold; else amount:=greatest(1,least(b.remaining_gold-(left_slots-1),floor(random()*((b.remaining_gold/left_slots)*2))+1)); end if;
 insert into room_luck_bag_claims(bag_id,user_id,amount_gold) values(b.id,auth.uid(),amount);
 update saki_account_modules set gold_coins=gold_coins+amount,updated_at=now() where user_id=auth.uid();
 update room_luck_bags set claimed_count=claimed_count+1,remaining_gold=remaining_gold-amount,status=case when claimed_count+1>=recipient_limit or remaining_gold-amount<=0 then 'empty' else 'open' end where id=b.id returning * into b;
 return query select b.id,amount,b.claimed_count,b.remaining_gold,b.status;
end; $$;

revoke all on function public.create_room_luck_bag(uuid,bigint,integer),public.claim_room_luck_bag(uuid) from public;
grant execute on function public.create_room_luck_bag(uuid,bigint,integer),public.claim_room_luck_bag(uuid) to authenticated;
