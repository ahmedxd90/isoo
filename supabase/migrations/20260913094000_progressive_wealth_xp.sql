-- Progressive wealth XP: the amount is charged for each level transition.
create or replace function public.wealth_xp_required_for_level(p_level integer)
returns numeric
language plpgsql immutable as $$
declare band integer; cost numeric;
begin
  if p_level <= 0 then return 0; end if;
  if p_level <= 10 then return 30000; end if;
  if p_level <= 20 then return 50000; end if;
  if p_level <= 30 then return 100000; end if;
  if p_level <= 40 then return 250000; end if;
  if p_level <= 50 then return 500000; end if;
  if p_level <= 60 then return 1000000; end if;
  if p_level <= 70 then return 2000000; end if;
  band := 70;
  cost := 2000000;
  while p_level > band loop
    band := band + 10;
    cost := cost * 2;
  end loop;
  return cost;
end; $$;

create or replace function public.level_from_xp(p_xp numeric, p_kind text)
returns integer language plpgsql immutable as $$
declare level_no integer := 0; total numeric := 0; cost numeric;
begin
  if p_kind <> 'wealth' then
    for i in 1..500 loop
      cost := 20000 * power(2, i - 1);
      exit when p_xp < total + cost;
      total := total + cost; level_no := i;
    end loop;
    return level_no;
  end if;
  for i in 1..500 loop
    cost := public.wealth_xp_required_for_level(i);
    exit when p_xp < total + cost;
    total := total + cost; level_no := i;
  end loop;
  return level_no;
end; $$;

create or replace function public.sync_user_levels(p_user_id uuid)
returns void language plpgsql security definer set search_path=public as $$
declare wxp bigint; cxp bigint; wl integer; cl integer;
begin
  select wealth_xp, charm_xp into wxp, cxp from public.saki_account_modules where user_id=p_user_id;
  wxp := coalesce(wxp,0); cxp := coalesce(cxp,0);
  wl := public.level_from_xp(wxp,'wealth'); cl := public.level_from_xp(cxp,'charm');
  update public.saki_account_modules set wealth_level=wl,charm_level=cl,updated_at=now() where user_id=p_user_id;
  update public.profiles set wealth_xp=wxp,wealth_level=wl,charm_xp=cxp,charm_level=cl,updated_at=now() where id=p_user_id;
end; $$;

-- Recalculate already stored levels using the new progression.
do $$ declare r record; begin for r in select user_id from public.saki_account_modules loop perform public.sync_user_levels(r.user_id); end loop; end $$;
