create or replace function public.family_gift_leaderboard(
  p_family_id uuid,
  p_mode text default 'sender'
)
returns table(user_id uuid, username text, avatar_url text, gold_total bigint)
language sql security definer set search_path = public
as $$
  select p.id, p.username, p.avatar_url,
         coalesce(sum(g.total_price), 0)::bigint
  from public.family_members fm
  join public.profiles p on p.id = fm.user_id
  left join public.room_gifts g on
    (case when p_mode = 'receiver' then g.recipient_id else g.sender_id end) = p.id
  where fm.family_id = p_family_id and fm.status = 'active'
  group by p.id, p.username, p.avatar_url
  order by 4 desc
  limit 10;
$$;
grant execute on function public.family_gift_leaderboard(uuid, text) to authenticated;
