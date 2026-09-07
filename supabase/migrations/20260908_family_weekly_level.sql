alter table public.families add column if not exists weekly_level integer not null default 0;
create or replace function public.family_weekly_level_for_gold(p_gold bigint)
returns integer language sql immutable as $$
  select case when coalesce(p_gold,0)>=25000000 then 5 when p_gold>=10000000 then 4 when p_gold>=5000000 then 3 when p_gold>=3000000 then 2 when p_gold>=1000000 then 1 else 0 end;
$$;
update public.families f set weekly_level=public.family_weekly_level_for_gold(coalesce((select sum(g.total_price)::bigint from public.family_members fm left join public.rooms r on r.owner_id=f.owner_id and r.is_active=true left join public.room_gifts g on g.room_id=r.id and g.sender_id=fm.user_id and g.created_at>=date_trunc('week',now()) where fm.family_id=f.id and fm.status='active'),0)::bigint);
