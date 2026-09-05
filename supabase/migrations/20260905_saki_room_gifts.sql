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

insert into public.room_gift_catalog(category,name,icon,price,sort_order) values
('general','وردة','🌹',100,1),('general','قلب','💖',500,2),('general','تاج','👑',1000,3),
('luck','حظ سعيد','🍀',250,1),('luck','صندوق الحظ','🎁',2500,2),('luck','نرد ذهبي','🎲',5000,3),
('famous','نجمة الشهرة','⭐',10000,1),('famous','مايك ذهبي','🎤',25000,2),
('countries','علم عربي','🏳️',300,1),('countries','كرة العالم','🌍',1500,2),
('vip','VIP لامع','💎',50000,1),('vip','VIP ملكي','💎',250000,2),
('cp','CP صغير','🪙',1000,1),('cp','CP ملكي','🪙',10000,2)
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
