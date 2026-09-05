alter table public.room_gifts add column if not exists recipient_diamonds bigint not null default 0;
create table if not exists public.gift_announcements (
  id uuid primary key default gen_random_uuid(),
  room_id uuid not null references public.rooms(id) on delete cascade,
  sender_id uuid not null references public.profiles(id),
  recipient_id uuid not null references public.profiles(id),
  gift_id uuid not null references public.room_gift_catalog(id),
  total_price bigint not null,
  recipient_diamonds bigint not null,
  created_at timestamptz not null default now()
);
alter table public.gift_announcements enable row level security;
drop policy if exists gift_announcements_read on public.gift_announcements;
create policy gift_announcements_read on public.gift_announcements for select to authenticated using (true);

create or replace function public.send_room_gift(p_room_id uuid, p_recipient_id uuid, p_gift_id uuid, p_quantity integer default 1)
returns table(gold_coins bigint, gift_name text, total_price bigint, recipient_diamonds bigint)
language plpgsql security definer set search_path = public as $$
declare g room_gift_catalog%rowtype; v_total bigint; v_reward bigint; sender_ok boolean; recipient_ok boolean;
begin
 if p_quantity is null or p_quantity < 1 or p_quantity > 99 then raise exception 'invalid_quantity'; end if;
 select * into g from public.room_gift_catalog where id=p_gift_id and is_active=true;
 if g.id is null then raise exception 'gift_not_found'; end if;
 select exists(select 1 from public.room_members where room_id=p_room_id and user_id=auth.uid()) into sender_ok;
 select exists(select 1 from public.room_members where room_id=p_room_id and user_id=p_recipient_id) into recipient_ok;
 if not sender_ok then raise exception 'sender_room_member_required'; end if;
 if not recipient_ok and p_recipient_id <> auth.uid() then raise exception 'room_member_required'; end if;
 v_total := g.price * p_quantity;
 v_reward := floor(v_total * 0.60);
 update public.saki_account_modules m set gold_coins=m.gold_coins-v_total, updated_at=now() where m.user_id=auth.uid() and m.gold_coins >= v_total;
 if not found then raise exception 'insufficient_gold'; end if;
 insert into public.saki_account_modules(user_id,diamonds) values(p_recipient_id,v_reward) on conflict(user_id) do update set diamonds=public.saki_account_modules.diamonds+excluded.diamonds,updated_at=now();
 insert into public.room_gifts(room_id,sender_id,recipient_id,gift_id,quantity,total_price,recipient_diamonds) values(p_room_id,auth.uid(),p_recipient_id,p_gift_id,p_quantity,v_total,v_reward);
 insert into public.room_gift_inventory(user_id,gift_id,quantity) values(p_recipient_id,p_gift_id,p_quantity) on conflict(user_id,gift_id) do update set quantity=public.room_gift_inventory.quantity+excluded.quantity;
 insert into public.gift_announcements(room_id,sender_id,recipient_id,gift_id,total_price,recipient_diamonds) values(p_room_id,auth.uid(),p_recipient_id,p_gift_id,v_total,v_reward);
 return query select m.gold_coins,g.name,v_total,v_reward from public.saki_account_modules m where m.user_id=auth.uid();
end; $$;
revoke all on function public.send_room_gift(uuid,uuid,uuid,integer) from public;
grant execute on function public.send_room_gift(uuid,uuid,uuid,integer) to authenticated;
