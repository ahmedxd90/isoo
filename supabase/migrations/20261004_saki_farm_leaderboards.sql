-- Real winner rankings for SAKI Farm (wheel game).
-- The current-round function is updated below to use a 30s betting phase and 5s result phase.
create or replace function public.saki_wheel_round_leaderboard(
  p_round_id bigint,
  p_limit integer default 3
)
returns table(
  rank_no integer,
  user_id uuid,
  username text,
  avatar_url text,
  gold_won bigint
)
language sql
security definer
set search_path = public
as $$
  with winners as (
    select
      b.user_id,
      sum(
        b.amount * case r.winning_food
          when 'burger' then 45
          when 'tomato' then 100
          when 'cake' then 25
          when 'pizza' then 15
          when 'shrimp' then 10
          when 'ice_cream' then 7
          when 'orange' then 5
          when 'corn' then 5
          else 3
        end
      )::bigint as gold_won
    from public.saki_wheel_bets b
    join public.saki_wheel_rounds r on r.id = b.round_id
    where b.round_id = p_round_id and b.food_key = r.winning_food
    group by b.user_id
  )
  select
    row_number() over (order by w.gold_won desc, w.user_id)::integer,
    w.user_id,
    coalesce(p.display_name, p.username, 'مستخدم')::text,
    p.avatar_url,
    w.gold_won
  from winners w
  left join public.profiles p on p.id = w.user_id
  order by w.gold_won desc, w.user_id
  limit greatest(1, least(coalesce(p_limit, 3), 3));
$$;

create or replace function public.saki_wheel_leaderboard(
  p_period text default 'daily',
  p_limit integer default 100
)
returns table(
  rank_no integer,
  user_id uuid,
  username text,
  avatar_url text,
  gold_won bigint
)
language sql
security definer
set search_path = public
as $$
  with winners as (
    select
      b.user_id,
      sum(
        b.amount * case r.winning_food
          when 'burger' then 45
          when 'tomato' then 100
          when 'cake' then 25
          when 'pizza' then 15
          when 'shrimp' then 10
          when 'ice_cream' then 7
          when 'orange' then 5
          when 'corn' then 5
          else 3
        end
      )::bigint as gold_won
    from public.saki_wheel_bets b
    join public.saki_wheel_rounds r on r.id = b.round_id
    where b.food_key = r.winning_food
      and b.created_at >= case
        when lower(coalesce(p_period, 'daily')) = 'weekly' then now() - interval '7 days'
        else date_trunc('day', now())
      end
    group by b.user_id
  )
  select
    row_number() over (order by w.gold_won desc, w.user_id)::integer,
    w.user_id,
    coalesce(p.display_name, p.username, 'مستخدم')::text,
    p.avatar_url,
    w.gold_won
  from winners w
  left join public.profiles p on p.id = w.user_id
  order by w.gold_won desc, w.user_id
  limit greatest(1, least(coalesce(p_limit, 100), 100));
$$;

revoke all on function public.saki_wheel_round_leaderboard(bigint, integer), public.saki_wheel_leaderboard(text, integer) from public;
grant execute on function public.saki_wheel_round_leaderboard(bigint, integer), public.saki_wheel_leaderboard(text, integer) to authenticated;
