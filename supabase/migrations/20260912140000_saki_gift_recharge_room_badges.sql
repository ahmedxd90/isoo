create table if not exists public.verified_gold_recharge_events (
  id uuid primary key default gen_random_uuid(), user_id uuid not null references public.profiles(id) on delete cascade,
  gold_coins bigint not null check (gold_coins > 0), source text not null check (source in ('google_play','shipping_agent')),
  provider_transaction_id text, verified boolean not null default false, metadata jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now(), verified_at timestamptz
);
create unique index if not exists verified_gold_recharge_provider_uidx on public.verified_gold_recharge_events(source,provider_transaction_id) where provider_transaction_id is not null;
alter table public.verified_gold_recharge_events enable row level security;
drop policy if exists verified_gold_recharge_own_read on public.verified_gold_recharge_events;
create policy verified_gold_recharge_own_read on public.verified_gold_recharge_events for select to authenticated using (user_id=auth.uid());

insert into public.badge_catalog(badge_key,name,description,category,target,asset_path,sort_order) values
('gift_sent_1m','مرسل الهدايا 1M','أرسل هدايا بقيمة مليون عملة ذهبية أو أكثر','gift_sent',1000000,'assets/badges/gifts/gift_1m.png',200),
('gift_sent_10m','مرسل الهدايا 10M','أرسل هدايا بقيمة عشرة ملايين عملة ذهبية أو أكثر','gift_sent',10000000,'assets/badges/gifts/gift_10m.png',210),
('gift_sent_50m','مرسل الهدايا 50M','أرسل هدايا بقيمة خمسين مليون عملة ذهبية أو أكثر','gift_sent',50000000,'assets/badges/gifts/gift_50m.png',220),
('gift_sent_100m','مرسل الهدايا 100M','أرسل هدايا بقيمة مئة مليون عملة ذهبية أو أكثر','gift_sent',100000000,'assets/badges/gifts/gift_100m.png',230),
('first_recharge_7500','أول شحنة','أتم أول شحن موثق بقيمة 7500 عملة ذهبية أو أكثر','recharge',7500,'assets/badges/recharge/first_7500.png',240),
('recharge_1m','شاحن 1M','شحن مليون عملة ذهبية أو أكثر','recharge',1000000,'assets/badges/recharge/recharge_1m.png',250),
('recharge_10m','شاحن 10M','شحن عشرة ملايين عملة ذهبية أو أكثر','recharge',10000000,'assets/badges/recharge/recharge_10m.png',260),
('recharge_50m','شاحن 50M','شحن خمسين مليون عملة ذهبية أو أكثر','recharge',50000000,'assets/badges/recharge/recharge_50m.png',270),
('recharge_100m','شاحن 100M','شحن مئة مليون عملة ذهبية أو أكثر','recharge',100000000,'assets/badges/recharge/recharge_100m.png',280),
('room_owner_gift_1m','مالك الغرفة 1M','استقبلت غرفتك هدايا بقيمة مليون عملة ذهبية أو أكثر','room_owner_gift',1000000,'assets/badges/rooms/room_gift_1m.png',300),
('room_owner_gift_10m','مالك الغرفة 10M','استقبلت غرفتك هدايا بقيمة عشرة ملايين عملة ذهبية أو أكثر','room_owner_gift',10000000,'assets/badges/rooms/room_gift_10m.png',310),
('room_owner_gift_50m','مالك الغرفة 50M','استقبلت غرفتك هدايا بقيمة خمسين مليون عملة ذهبية أو أكثر','room_owner_gift',50000000,'assets/badges/rooms/room_gift_50m.png',320),
('room_owner_gift_100m','مالك الغرفة 100M','استقبلت غرفتك هدايا بقيمة مئة مليون عملة ذهبية أو أكثر','room_owner_gift',100000000,'assets/badges/rooms/room_gift_100m.png',330),
('title_gift_patron','لقب راعي الهدايا','لقب فاخر لمرسلي الهدايا المميزين','title',1000000,'assets/badges/titles/gift_patron.png',400),
('title_recharge_master','لقب سيد الشحن','لقب فاخر لأصحاب الشحن الموثق','title',1000000,'assets/badges/titles/recharge_master.png',410),
('title_room_owner','لقب مالك الغرفة','لقب فاخر لمالكي الغرف النشطة','title',1000000,'assets/badges/titles/room_owner.png',420),
('title_elite_legend','لقب الأسطورة النخبة','لقب نخبوي لإنجازات SAKI الكبرى','title',100000000,'assets/badges/titles/elite_legend.png',430)
on conflict (badge_key) do update set name=excluded.name,description=excluded.description,category=excluded.category,target=excluded.target,asset_path=excluded.asset_path,sort_order=excluded.sort_order,is_active=true;

create or replace function public.evaluate_user_badges(p_user_id uuid) returns void language plpgsql security definer set search_path=public as $$
declare r record; v_value bigint; v_streak integer:=0; v_day date:=current_date; v_has boolean; v_last date;
begin
 select max(claim_date) into v_last from public.user_daily_login_rewards where user_id=p_user_id;
 if v_last is not null then v_day:=v_last; loop select exists(select 1 from public.user_daily_login_rewards where user_id=p_user_id and claim_date=v_day) into v_has; exit when not v_has; v_streak:=v_streak+1; v_day:=v_day-1; end loop; end if;
 for r in select badge_key,target,category,asset_path,name,description from public.badge_catalog where is_active loop
  v_value:=case r.category
   when 'login' then v_streak
   when 'seat' then coalesce((select sum(duration_seconds) from public.room_seat_sessions where user_id=p_user_id),0)+coalesce((select extract(epoch from(now()-joined_at))::bigint from public.room_seats where user_id=p_user_id limit 1),0)
   when 'post' then (select count(*) from public.posts where author_id=p_user_id)
   when 'reel' then (select count(*) from public.reels where author_id=p_user_id)
   when 'admin' then case when exists(select 1 from public.profiles where id=p_user_id and is_super_admin) then 1 else 0 end
   when 'gift_sent' then coalesce((select sum(total_price) from public.room_gifts where sender_id=p_user_id),0)
   when 'recharge' then coalesce((select sum(gold_coins) from public.shipping_transactions where recipient_id=p_user_id),0)+coalesce((select sum(gold_coins) from public.verified_gold_recharge_events where user_id=p_user_id and verified),0)
   when 'room_owner_gift' then coalesce((select sum(g.total_price) from public.room_gifts g join public.rooms rm on rm.id=g.room_id where rm.owner_id=p_user_id),0)
   when 'title' then greatest(coalesce((select sum(total_price) from public.room_gifts where sender_id=p_user_id),0),coalesce((select sum(gold_coins) from public.shipping_transactions where recipient_id=p_user_id),0)+coalesce((select sum(gold_coins) from public.verified_gold_recharge_events where user_id=p_user_id and verified),0),coalesce((select sum(g.total_price) from public.room_gifts g join public.rooms rm on rm.id=g.room_id where rm.owner_id=p_user_id),0))
   else 0 end;
  if v_value>=r.target and not exists(select 1 from public.user_badges where user_id=p_user_id and badge_key=r.badge_key) then
   insert into public.user_badges(user_id,badge_key) values(p_user_id,r.badge_key);
   insert into public.notifications(user_id,actor_id,type,badge_key,badge_asset_path,is_read,data) values(p_user_id,p_user_id,'badge_earned',r.badge_key,r.asset_path,false,jsonb_build_object('badge_key',r.badge_key,'name',r.name,'description',r.description));
  end if;
 end loop;
end; $$;

create or replace function public.badges_after_gift() returns trigger language plpgsql security definer set search_path=public as $$ declare room_owner uuid; begin perform public.evaluate_user_badges(new.sender_id); select owner_id into room_owner from public.rooms where id=new.room_id; if room_owner is not null and room_owner<>new.sender_id then perform public.evaluate_user_badges(room_owner); end if; return new; end; $$;
drop trigger if exists real_badges_gifts on public.room_gifts;
create trigger real_badges_gifts after insert on public.room_gifts for each row execute function public.badges_after_gift();
create or replace function public.badges_after_shipping() returns trigger language plpgsql security definer set search_path=public as $$ begin perform public.evaluate_user_badges(new.recipient_id); return new; end; $$;
drop trigger if exists real_badges_shipping on public.shipping_transactions;
create trigger real_badges_shipping after insert on public.shipping_transactions for each row execute function public.badges_after_shipping();
create or replace function public.badges_after_verified_recharge() returns trigger language plpgsql security definer set search_path=public as $$ begin if new.verified then perform public.evaluate_user_badges(new.user_id); end if; return new; end; $$;
drop trigger if exists real_badges_verified_recharge on public.verified_gold_recharge_events;
create trigger real_badges_verified_recharge after insert or update of verified on public.verified_gold_recharge_events for each row execute function public.badges_after_verified_recharge();
revoke all on function public.evaluate_user_badges(uuid) from public;
grant execute on function public.evaluate_user_badges(uuid) to authenticated;
revoke all on public.verified_gold_recharge_events from anon,authenticated;
grant select on public.verified_gold_recharge_events to authenticated;
do $$ declare p record; begin for p in select id from public.profiles loop perform public.evaluate_user_badges(p.id); end loop; end $$;
comment on table public.verified_gold_recharge_events is 'Trusted server-side Google Play or shipping recharge events; only verified rows count.';
grant execute on function public.user_badges_for_profile(uuid) to authenticated;
select 1;
