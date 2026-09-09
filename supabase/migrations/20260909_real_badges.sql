create table if not exists public.badge_catalog (
  badge_key text primary key,
  name text not null,
  description text not null,
  category text not null,
  target bigint not null default 1,
  asset_path text not null,
  sort_order integer not null default 0,
  is_active boolean not null default true,
  created_at timestamptz not null default now()
);

create table if not exists public.user_badges (
  user_id uuid not null references public.profiles(id) on delete cascade,
  badge_key text not null references public.badge_catalog(badge_key) on delete cascade,
  earned_at timestamptz not null default now(),
  primary key (user_id, badge_key)
);

create table if not exists public.room_seat_sessions (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references public.profiles(id) on delete cascade,
  room_id uuid not null references public.rooms(id) on delete cascade,
  started_at timestamptz not null,
  ended_at timestamptz not null default now(),
  duration_seconds bigint not null check (duration_seconds >= 0),
  created_at timestamptz not null default now()
);

insert into public.badge_catalog(badge_key,name,description,category,target,asset_path,sort_order) values
('login_7_days','تسجيل دخول 7 أيام','سجّل دخولك سبعة أيام متتالية','login',7,'assets/badges/login_7_days.png',10),
('login_14_days','تسجيل دخول 14 يوم','سجّل دخولك أربعة عشر يومًا متتاليًا','login',14,'assets/badges/login_14_days.png',20),
('login_365_days','تسجيل دخول 365 يوم','حافظت على حضورك لمدة عام كامل','login',365,'assets/badges/login_365_days.png',30),
('seat_1_hour','متحدث على المقعد ساعة','تحدثت على مقعد صوتي لمدة ساعة','seat',3600,'assets/badges/seat_1_hour.png',40),
('seat_24_hours','متحدث على المقعد 24 ساعة','تحدثت على مقعد صوتي لمدة 24 ساعة','seat',86400,'assets/badges/seat_24_hours.png',50),
('seat_14_days','متحدث على المقعد 14 يوم','تحدثت على المقاعد لمدة 14 يومًا','seat',1209600,'assets/badges/seat_14_days.png',60),
('seat_365_days','متحدث على المقعد 365 يوم','تحدثت على المقاعد لمدة عام كامل','seat',31536000,'assets/badges/seat_365_days.png',70),
('post_1','أول منشور في اللحظات','نشرت أول منشور لك في اللحظات','post',1,'assets/badges/post_1.png',80),
('post_100','100 منشور في اللحظات','نشرت 100 منشور في اللحظات','post',100,'assets/badges/post_100.png',90),
('post_1000','1000 منشور في اللحظات','نشرت 1000 منشور في اللحظات','post',1000,'assets/badges/post_1000.png',100),
('reel_1','أول ريلز','نشرت أول ريلز لك','reel',1,'assets/badges/reel_1.png',110),
('reel_100','100 ريلز','نشرت 100 ريلز','reel',100,'assets/badges/reel_100.png',120),
('super_admin','السوبر أدمن','وسام خاص بحسابات السوبر أدمن فقط','admin',1,'assets/badges/super_admin.png',130)
on conflict (badge_key) do update set name=excluded.name,description=excluded.description,target=excluded.target,asset_path=excluded.asset_path,sort_order=excluded.sort_order,is_active=true;

alter table public.badge_catalog enable row level security;
alter table public.user_badges enable row level security;
alter table public.room_seat_sessions enable row level security;
drop policy if exists badge_catalog_read on public.badge_catalog;
create policy badge_catalog_read on public.badge_catalog for select to authenticated using (is_active=true);
drop policy if exists user_badges_read on public.user_badges;
create policy user_badges_read on public.user_badges for select to authenticated using (true);
drop policy if exists seat_sessions_own_read on public.room_seat_sessions;
create policy seat_sessions_own_read on public.room_seat_sessions for select to authenticated using (user_id=auth.uid());

create or replace function public.evaluate_user_badges(p_user_id uuid)
returns void language plpgsql security definer set search_path=public as $$
declare r record; v_value bigint; v_streak integer:=0; v_day date:=current_date; v_has boolean; v_last date;
begin
  select max(claim_date) into v_last from public.user_daily_login_rewards where user_id=p_user_id;
  if v_last is not null then
    v_day:=v_last;
    loop
      select exists(select 1 from public.user_daily_login_rewards where user_id=p_user_id and claim_date=v_day) into v_has;
      exit when not v_has;
      v_streak:=v_streak+1; v_day:=v_day-1;
    end loop;
  end if;
  for r in select badge_key,target,category from public.badge_catalog where is_active=true loop
    v_value:=case r.category
      when 'login' then v_streak
      when 'seat' then coalesce((select sum(duration_seconds) from public.room_seat_sessions where user_id=p_user_id),0)+coalesce((select extract(epoch from (now()-started_at))::bigint from public.room_seats where user_id=p_user_id),0)
      when 'post' then (select count(*) from public.posts where author_id=p_user_id)
      when 'reel' then (select count(*) from public.reels where author_id=p_user_id)
      when 'admin' then case when exists(select 1 from public.profiles where id=p_user_id and is_super_admin=true) then 1 else 0 end
      else 0 end;
    if v_value >= r.target and not exists(select 1 from public.user_badges where user_id=p_user_id and badge_key=r.badge_key) then
      insert into public.user_badges(user_id,badge_key) values(p_user_id,r.badge_key);
      insert into public.notifications(user_id,actor_id,type,entity_id,is_read)
      values(p_user_id,p_user_id,'badge_earned',null,false);
    end if;
  end loop;
end; $$;

create or replace function public.badges_after_activity() returns trigger language plpgsql security definer set search_path=public as $$
begin
  perform public.evaluate_user_badges(case when tg_table_name='posts' then new.author_id when tg_table_name='reels' then new.author_id else new.user_id end);
  return new;
end; $$;

drop trigger if exists real_badges_posts on public.posts;
create trigger real_badges_posts after insert on public.posts for each row execute function public.badges_after_activity();
drop trigger if exists real_badges_reels on public.reels;
create trigger real_badges_reels after insert on public.reels for each row execute function public.badges_after_activity();

create or replace function public.record_room_seat_session() returns trigger language plpgsql security definer set search_path=public as $$
declare v_seconds bigint:=greatest(extract(epoch from (now()-old.joined_at))::bigint,0);
begin
  insert into public.room_seat_sessions(user_id,room_id,started_at,ended_at,duration_seconds) values(old.user_id,old.room_id,old.joined_at,now(),v_seconds);
  perform public.evaluate_user_badges(old.user_id);
  return old;
end; $$;
drop trigger if exists real_badges_seat_session on public.room_seats;
create trigger real_badges_seat_session after delete on public.room_seats for each row execute function public.record_room_seat_session();

create or replace function public.evaluate_badges_after_login() returns trigger language plpgsql security definer set search_path=public as $$
begin perform public.evaluate_user_badges(new.user_id); return new; end; $$;
drop trigger if exists real_badges_login on public.user_daily_login_rewards;
create trigger real_badges_login after insert on public.user_daily_login_rewards for each row execute function public.evaluate_badges_after_login();

create or replace function public.user_badges_for_profile(p_user_id uuid)
returns table(badge_key text,name text,description text,category text,target bigint,asset_path text,earned_at timestamptz)
language sql security definer set search_path=public as $$
select c.badge_key,c.name,c.description,c.category,c.target,c.asset_path,u.earned_at
from public.user_badges u join public.badge_catalog c using(badge_key)
where u.user_id=p_user_id order by c.sort_order,u.earned_at;
$$;
revoke all on function public.user_badges_for_profile(uuid) from public;
grant execute on function public.user_badges_for_profile(uuid) to authenticated;

create or replace function public.badge_notification_rows()
returns table(id uuid,user_id uuid,actor_id uuid,type text,entity_id uuid,is_read boolean,created_at timestamptz,badge_key text,name text,description text,asset_path text,earned_at timestamptz)
language sql security definer set search_path=public as $$
select n.id,n.user_id,n.actor_id,n.type,n.entity_id,n.is_read,n.created_at,c.badge_key,c.name,c.description,c.asset_path,u.earned_at
from public.notifications n join public.user_badges u on u.user_id=n.user_id and n.type='badge_earned' join public.badge_catalog c using(badge_key)
where n.user_id=auth.uid() order by n.created_at desc limit 100;
$$;

-- The notification table intentionally remains backward-compatible; the Flutter client resolves badge_earned to the latest earned badge.

alter table public.notifications add column if not exists badge_key text references public.badge_catalog(badge_key);
alter table public.notifications add column if not exists badge_asset_path text;
create or replace function public.evaluate_user_badges(p_user_id uuid)
returns void language plpgsql security definer set search_path=public as $$
declare r record; v_value bigint; v_streak integer:=0; v_day date:=current_date; v_has boolean; v_last date;
begin
  select max(claim_date) into v_last from public.user_daily_login_rewards where user_id=p_user_id;
  if v_last is not null then v_day:=v_last; loop select exists(select 1 from public.user_daily_login_rewards where user_id=p_user_id and claim_date=v_day) into v_has; exit when not v_has; v_streak:=v_streak+1; v_day:=v_day-1; end loop; end if;
  for r in select badge_key,target,category,asset_path from public.badge_catalog where is_active=true loop
    v_value:=case r.category when 'login' then v_streak when 'seat' then coalesce((select sum(duration_seconds) from public.room_seat_sessions where user_id=p_user_id),0)+coalesce((select extract(epoch from (now()-joined_at))::bigint from public.room_seats where user_id=p_user_id limit 1),0) when 'post' then (select count(*) from public.posts where author_id=p_user_id) when 'reel' then (select count(*) from public.reels where author_id=p_user_id) when 'admin' then case when exists(select 1 from public.profiles where id=p_user_id and is_super_admin=true) then 1 else 0 end else 0 end;
    if v_value>=r.target and not exists(select 1 from public.user_badges where user_id=p_user_id and badge_key=r.badge_key) then
      insert into public.user_badges(user_id,badge_key) values(p_user_id,r.badge_key);
      insert into public.notifications(user_id,actor_id,type,badge_key,badge_asset_path,is_read) values(p_user_id,p_user_id,'badge_earned',r.badge_key,r.asset_path,false);
    end if;
  end loop;
end; $$;
-- The notification table remains backward-compatible; badge_key and badge_asset_path identify the exact earned badge.
