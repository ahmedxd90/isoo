create or replace function public.global_gift_user_leaderboard_v2(
  p_period text default 'daily',
  p_mode text default 'wealth'
)
returns table(
  user_id uuid,
  username text,
  avatar_url text,
  vip_level integer,
  wealth_level integer,
  charm_level integer,
  total_gold bigint,
  rank_position bigint,
  is_current_user boolean
)
language sql
stable
security definer
set search_path = public, pg_temp
as $function$
with clock as (
  select now() as now_at, date_trunc('day', now()) as day_start
), bounds as (
  select
    case lower(coalesce(p_period, 'daily'))
      when 'yesterday' then c.day_start - interval '1 day'
      when 'weekly' then c.now_at - interval '7 days'
      when 'monthly' then c.now_at - interval '30 days'
      else c.day_start
    end as since_at,
    case lower(coalesce(p_period, 'daily'))
      when 'yesterday' then c.day_start
      else c.now_at
    end as until_at
  from clock c
), totals as (
  select
    case when lower(coalesce(p_mode, 'wealth')) = 'charm'
      then g.recipient_id else g.sender_id end as ranked_user_id,
    sum(g.total_price)::bigint as amount
  from public.room_gifts g
  cross join bounds b
  where g.created_at >= b.since_at
    and g.created_at < b.until_at
  group by 1
), ranked as (
  select
    p.id as ranked_user_id,
    p.username,
    p.avatar_url,
    coalesce(p.vip_level, 0)::integer as vip_level,
    coalesce(p.wealth_level, 0)::integer as wealth_level,
    coalesce(p.charm_level, 0)::integer as charm_level,
    t.amount as total_gold,
    row_number() over (order by t.amount desc, p.id) as rank_position
  from totals t
  join public.profiles p on p.id = t.ranked_user_id
)
select
  r.ranked_user_id,
  r.username,
  r.avatar_url,
  r.vip_level,
  r.wealth_level,
  r.charm_level,
  r.total_gold,
  r.rank_position,
  (r.ranked_user_id = auth.uid()) as is_current_user
from ranked r
where r.rank_position <= 100 or r.ranked_user_id = auth.uid()
order by r.rank_position;
$function$;

revoke all on function public.global_gift_user_leaderboard_v2(text, text) from public, anon;
grant execute on function public.global_gift_user_leaderboard_v2(text, text) to authenticated;
comment on function public.global_gift_user_leaderboard_v2(text, text) is
  'Read-only global wealth/charm gift leaderboard, top 100 plus the authenticated user, with daily/weekly/monthly/yesterday periods.';

create or replace function public.global_gift_room_leaderboard_v2(
  p_period text default 'daily'
)
returns table(
  room_id uuid,
  name text,
  room_code text,
  image_url text,
  total_gold bigint,
  rank_position bigint,
  is_my_room boolean
)
language sql
stable
security definer
set search_path = public, pg_temp
as $function$
with clock as (
  select now() as now_at, date_trunc('day', now()) as day_start
), bounds as (
  select
    case lower(coalesce(p_period, 'daily'))
      when 'yesterday' then c.day_start - interval '1 day'
      when 'weekly' then c.now_at - interval '7 days'
      when 'monthly' then c.now_at - interval '30 days'
      else c.day_start
    end as since_at,
    case lower(coalesce(p_period, 'daily'))
      when 'yesterday' then c.day_start
      else c.now_at
    end as until_at
  from clock c
), totals as (
  select g.room_id, sum(g.total_price)::bigint as amount
  from public.room_gifts g
  join public.rooms rm on rm.id = g.room_id and rm.is_active = true
  cross join bounds b
  where g.created_at >= b.since_at
    and g.created_at < b.until_at
  group by g.room_id
), ranked as (
  select
    rm.id as ranked_room_id,
    rm.name,
    rm.room_id as room_code,
    rm.image_url,
    t.amount as total_gold,
    rm.owner_id,
    row_number() over (order by t.amount desc, rm.id) as rank_position
  from totals t
  join public.rooms rm on rm.id = t.room_id and rm.is_active = true
)
select
  r.ranked_room_id,
  r.name,
  r.room_code,
  r.image_url,
  r.total_gold,
  r.rank_position,
  (r.owner_id = auth.uid()) as is_my_room
from ranked r
where r.rank_position <= 100 or r.owner_id = auth.uid()
order by r.rank_position;
$function$;

revoke all on function public.global_gift_room_leaderboard_v2(text) from public, anon;
grant execute on function public.global_gift_room_leaderboard_v2(text) to authenticated;
comment on function public.global_gift_room_leaderboard_v2(text) is
  'Read-only active room leaderboard by gold gifts, top 100 plus the authenticated user’s rooms, with daily/weekly/monthly/yesterday periods.';
