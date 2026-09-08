-- Family levels are displayed as LV1..LV10; level zero violates families_level_check.
create or replace function public.family_level_for_points(p_points bigint)
returns integer language sql immutable as $$
  select case
    when coalesce(p_points,0) >= 500000000 then 10
    when p_points >= 250000000 then 9
    when p_points >= 150000000 then 8
    when p_points >= 100000000 then 7
    when p_points >= 50000000 then 6
    when p_points >= 25000000 then 5
    when p_points >= 15000000 then 4
    when p_points >= 10000000 then 3
    when p_points >= 5000000 then 2
    when p_points >= 2000000 then 1
    else 1
  end;
$$;
alter table public.families alter column level set default 1;
update public.families set level=1 where level<1;
