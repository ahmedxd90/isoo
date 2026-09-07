create or replace function public.global_gift_user_leaderboard(
  p_period text default 'daily',
  p_mode text default 'wealth'
)
returns table(user_id uuid, username text, avatar_url text, vip_level integer, total_gold bigint)
language sql security definer set search_path = public
as $$
with bounds as (
  select case lower(p_period)
    when 'weekly' then now() - interval '7 days'
    when 'monthly' then now() - interval '30 days'
    else date_trunc('day', now())
  end as since
), totals as (
  select case when lower(p_mode) = 'charm' then g.recipient_id else g.sender_id end as uid,
         sum(g.total_price)::bigint as amount
  from public.room_gifts g, bounds b
  where g.created_at >= b.since
  group by 1
)
select t.uid, p.username, p.avatar_url, coalesce(p.vip_level, 0)::integer, t.amount
from totals t join public.profiles p on p.id = t.uid
order by t.amount desc limit 50
$$;
revoke all on function public.global_gift_user_leaderboard(text, text) from public;
grant execute on function public.global_gift_user_leaderboard(text, text) to authenticated;

create or replace function public.global_gift_room_leaderboard(p_period text default 'daily')
returns table(room_id uuid, name text, room_code text, image_url text, total_gold bigint)
language sql security definer set search_path = public
as $$
with bounds as (
  select case lower(p_period)
    when 'weekly' then now() - interval '7 days'
    when 'monthly' then now() - interval '30 days'
    else date_trunc('day', now())
  end as since
)
select r.id, r.name, r.room_id, r.image_url, sum(g.total_price)::bigint
from public.room_gifts g
join public.rooms r on r.id = g.room_id, bounds b
where g.created_at >= b.since and r.is_active = true
group by r.id, r.name, r.room_id, r.image_url
order by sum(g.total_price) desc limit 50
$$;
revoke all on function public.global_gift_room_leaderboard(text) from public;
grant execute on function public.global_gift_room_leaderboard(text) to authenticated;
