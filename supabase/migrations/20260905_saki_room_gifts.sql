create table if not exists public.room_gift_catalog (
  id uuid primary key default gen_random_uuid(),
  category text not null check (category in ('general','luck','famous','countries','vip','cp')),
  name text not null,
  icon text not null,
  price bigint not null check (price > 0),
  sort_order integer not null default 0,
  is_active boolean not null default true
);
create table if not exists public.room_gifts (
  id uuid primary key default gen_random_uuid(),
  room_id uuid not null references public.rooms(id) on delete cascade,
  sender_id uuid not null references public.profiles(id),
  recipient_id uuid not null references public.profiles(id),
  gift_id uuid not null references public.room_gift_catalog(id),
  quantity integer not null default 1 check (quantity > 0),
  total_price bigint not null,
  created_at timestamptz not null default now()
);
create table if not exists public.room_gift_inventory (
  user_id uuid not null references public.profiles(id) on delete cascade,
  gift_id uuid not null references public.room_gift_catalog(id) on delete cascade,
  quantity bigint not null default 0,
  primary key(user_id, gift_id)
);
alter table public.room_gift_catalog enable row level security;
alter table public.room_gifts enable row level security;
alter table public.room_gift_inventory enable row level security;
drop policy if exists room_gift_catalog_read on public.room_gift_catalog;
create policy room_gift_catalog_read on public.room_gift_catalog for select using (is_active = true);
drop policy if exists room_gifts_room_read on public.room_gifts;
create policy room_gifts_room_read on public.room_gifts for select using (exists (select 1 from public.room_members m where m.room_id = room_gifts.room_id and m.user_id = auth.uid()));
drop policy if exists room_gift_inventory_own on public.room_gift_inventory;
create policy room_gift_inventory_own on public.room_gift_inventory for select using (user_id = auth.uid());

insert into public.room_gift_catalog(gift_type,display_name,category,price,emoji,name,icon,sort_order) values
('seed_01','وردة','general',100,'🌹','وردة','🌹',1),('seed_02','قلب','general',500,'💖','قلب','💖',2),('seed_03','تاج','general',1000,'👑','تاج','👑',3),
('seed_04','حظ سعيد','luck',250,'🍀','حظ سعيد','🍀',1),('seed_05','صندوق الحظ','luck',2500,'🎁','صندوق الحظ','🎁',2),('seed_06','نرد ذهبي','luck',5000,'🎲','نرد ذهبي','🎲',3),
('seed_07','نجمة الشهرة','famous',10000,'⭐','نجمة الشهرة','⭐',1),('seed_08','مايك ذهبي','famous',25000,'🎤','مايك ذهبي','🎤',2),
('seed_09','علم عربي','countries',300,'🏳️','علم عربي','🏳️',1),('seed_10','كرة العالم','countries',1500,'🌍','كرة العالم','🌍',2),
('seed_11','VIP لامع','vip',50000,'💎','VIP لامع','💎',1),('seed_12','VIP ملكي','vip',250000,'💎','VIP ملكي','💎',2),
('seed_13','CP صغير','cp',1000,'🪙','CP صغير','🪙',1),('seed_14','CP ملكي','cp',10000,'🪙','CP ملكي','🪙',2)
on conflict do nothing;

create or replace function public.send_room_gift(p_room_id uuid, p_recipient_id uuid, p_gift_id uuid, p_quantity integer default 1)
returns table(gold_coins bigint, gift_name text, total_price bigint)
language plpgsql security definer set search_path = public as $$
declare g room_gift_catalog%rowtype; total bigint; sender_ok boolean; recipient_ok boolean;
begin
 if p_quantity is null or p_quantity < 1 or p_quantity > 99 then raise exception 'invalid_quantity'; end if;
 select * into g from room_gift_catalog where id=p_gift_id and is_active=true;
 if g.id is null then raise exception 'gift_not_found'; end if;
 select exists(select 1 from room_members where room_id=p_room_id and user_id=auth.uid()) into sender_ok;
 select exists(select 1 from room_members where room_id=p_room_id and user_id=p_recipient_id) into recipient_ok;
 if not sender_ok or not recipient_ok then raise exception 'room_member_required'; end if;
 total := g.price * p_quantity;
 update saki_account_modules set gold_coins=gold_coins-total, updated_at=now() where user_id=auth.uid() and gold_coins >= total;
 if not found then raise exception 'insufficient_gold'; end if;
 insert into room_gifts(room_id,sender_id,recipient_id,gift_id,quantity,total_price) values(p_room_id,auth.uid(),p_recipient_id,p_gift_id,p_quantity,total);
 insert into room_gift_inventory(user_id,gift_id,quantity) values(p_recipient_id,p_gift_id,p_quantity) on conflict(user_id,gift_id) do update set quantity=room_gift_inventory.quantity+excluded.quantity;
 return query select m.gold_coins,g.name,total from saki_account_modules m where m.user_id=auth.uid();
end; $$;
revoke all on function public.send_room_gift(uuid,uuid,uuid,integer) from public;
grant execute on function public.send_room_gift(uuid,uuid,uuid,integer) to authenticated;
