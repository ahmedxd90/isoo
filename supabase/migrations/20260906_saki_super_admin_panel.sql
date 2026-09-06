-- SAKI Super Admin panel: secure administrative access to Trace feature data.
-- Every policy and RPC re-checks the database-backed super-admin flag.

create or replace function public.saki_admin_dashboard()
returns jsonb
language plpgsql security definer set search_path = public as $$
declare result jsonb;
begin
  if not public.is_saki_super_admin() then raise exception 'admin_required'; end if;
  select jsonb_build_object(
    'users', (select count(*) from public.profiles),
    'active_vip', (select count(*) from public.profiles where vip_level > 0 and (vip_expires_at is null or vip_expires_at > now())),
    'rooms', (select count(*) from public.rooms),
    'messages', (select count(*) from public.messages),
    'posts', (select count(*) from public.posts),
    'reels', (select count(*) from public.reels),
    'agencies', (select count(*) from public.trace_agencies where status = 'active'),
    'families', (select count(*) from public.trace_families where status = 'active'),
    'bans', (select count(*) from public.app_bans where expires_at is null or expires_at > now())
  ) into result;
  return result;
end; $$;

revoke all on function public.saki_admin_dashboard() from public;
grant execute on function public.saki_admin_dashboard() to authenticated;

-- Admin read/write policies for the feature tables. Normal users retain their existing policies.
do $$
begin
  execute 'drop policy if exists trace_store_catalog_admin on public.trace_store_catalog';
  execute 'create policy trace_store_catalog_admin on public.trace_store_catalog for all to authenticated using (public.is_saki_super_admin()) with check (public.is_saki_super_admin())';
  execute 'drop policy if exists trace_agencies_admin on public.trace_agencies';
  execute 'create policy trace_agencies_admin on public.trace_agencies for all to authenticated using (public.is_saki_super_admin()) with check (public.is_saki_super_admin())';
  execute 'drop policy if exists trace_agency_members_admin on public.trace_agency_members';
  execute 'create policy trace_agency_members_admin on public.trace_agency_members for all to authenticated using (public.is_saki_super_admin()) with check (public.is_saki_super_admin())';
  execute 'drop policy if exists trace_agency_requests_admin on public.trace_agency_join_requests';
  execute 'create policy trace_agency_requests_admin on public.trace_agency_join_requests for all to authenticated using (public.is_saki_super_admin()) with check (public.is_saki_super_admin())';
  execute 'drop policy if exists trace_families_admin on public.trace_families';
  execute 'create policy trace_families_admin on public.trace_families for all to authenticated using (public.is_saki_super_admin()) with check (public.is_saki_super_admin())';
  execute 'drop policy if exists trace_family_members_admin on public.trace_family_members';
  execute 'create policy trace_family_members_admin on public.trace_family_members for all to authenticated using (public.is_saki_super_admin()) with check (public.is_saki_super_admin())';
  execute 'drop policy if exists trace_user_levels_admin on public.trace_user_levels';
  execute 'create policy trace_user_levels_admin on public.trace_user_levels for all to authenticated using (public.is_saki_super_admin()) with check (public.is_saki_super_admin())';
  execute 'drop policy if exists trace_level_rewards_admin on public.trace_level_rewards';
  execute 'create policy trace_level_rewards_admin on public.trace_level_rewards for all to authenticated using (public.is_saki_super_admin()) with check (public.is_saki_super_admin())';
end $$;

create or replace function public.admin_set_user_level(p_user_id uuid, p_experience bigint)
returns void language plpgsql security definer set search_path = public as $$
begin
  if not public.is_saki_super_admin() or p_experience < 0 then raise exception 'admin_required'; end if;
  insert into public.trace_user_levels(user_id, experience_points) values (p_user_id, p_experience)
  on conflict (user_id) do update set experience_points = excluded.experience_points, updated_at = now();
end; $$;

create or replace function public.admin_set_agency_status(p_agency_id uuid, p_status text)
returns void language plpgsql security definer set search_path = public as $$
begin
  if not public.is_saki_super_admin() or p_status not in ('active','suspended','closed') then raise exception 'admin_required'; end if;
  update public.trace_agencies set status = p_status where id = p_agency_id;
end; $$;

create or replace function public.admin_set_family_status(p_family_id uuid, p_status text)
returns void language plpgsql security definer set search_path = public as $$
begin
  if not public.is_saki_super_admin() or p_status not in ('active','suspended','closed') then raise exception 'admin_required'; end if;
  update public.trace_families set status = p_status where id = p_family_id;
end; $$;

revoke all on function public.admin_set_user_level(uuid,bigint), public.admin_set_agency_status(uuid,text), public.admin_set_family_status(uuid,text) from public;
grant execute on function public.admin_set_user_level(uuid,bigint), public.admin_set_agency_status(uuid,text), public.admin_set_family_status(uuid,text) to authenticated;
