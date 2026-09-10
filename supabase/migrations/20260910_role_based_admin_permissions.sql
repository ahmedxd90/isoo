-- SAKI role-based administration: database-enforced permissions and audit trail.
-- Roles remain compatible with profiles.admin_role and the existing Super Admin flag.

create table if not exists public.admin_role_permissions (
  role text not null check (role in ('user','super_admin','admin','bd','official_host','customer_service')),
  permission text not null,
  created_at timestamptz not null default now(),
  primary key (role, permission)
);

create table if not exists public.admin_audit_log (
  id uuid primary key default gen_random_uuid(),
  actor_id uuid not null references public.profiles(id),
  action text not null,
  target_user_id uuid references public.profiles(id),
  metadata jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now()
);

create index if not exists admin_audit_log_created_at_idx
  on public.admin_audit_log(created_at desc);
create index if not exists admin_audit_log_actor_idx
  on public.admin_audit_log(actor_id, created_at desc);
create index if not exists admin_audit_log_target_idx
  on public.admin_audit_log(target_user_id, created_at desc);

alter table public.admin_role_permissions enable row level security;
alter table public.admin_audit_log enable row level security;

insert into public.admin_role_permissions(role, permission) values
  ('super_admin','view_users'),
  ('super_admin','manage_users'),
  ('super_admin','manage_user_roles'),
  ('super_admin','ban_users'),
  ('super_admin','manage_rooms'),
  ('super_admin','manage_reports'),
  ('super_admin','manage_content'),
  ('super_admin','manage_agencies'),
  ('super_admin','manage_families'),
  ('super_admin','manage_finance'),
  ('super_admin','manage_vip'),
  ('super_admin','manage_badges'),
  ('super_admin','manage_system'),
  ('super_admin','view_analytics'),
  ('super_admin','manage_official_broadcast'),
  ('super_admin','support_users'),
  ('admin','view_users'),
  ('admin','manage_users'),
  ('admin','ban_users'),
  ('admin','manage_rooms'),
  ('admin','manage_reports'),
  ('admin','manage_content'),
  ('admin','view_analytics'),
  ('bd','view_users'),
  ('bd','manage_agencies'),
  ('bd','manage_families'),
  ('bd','view_analytics'),
  ('official_host','view_users'),
  ('official_host','manage_rooms'),
  ('official_host','manage_official_broadcast'),
  ('official_host','view_analytics'),
  ('customer_service','view_users'),
  ('customer_service','manage_reports'),
  ('customer_service','support_users'),
  ('customer_service','view_analytics')
on conflict (role, permission) do nothing;

create or replace function public.saki_current_admin_role()
returns text
language sql stable security definer set search_path=public
as $$
  select case
    when exists (
      select 1 from public.profiles
      where id = auth.uid() and (is_super_admin = true or saki_id = 1000)
    ) then 'super_admin'
    else coalesce((select admin_role from public.profiles where id = auth.uid()), 'user')
  end;
$$;

create or replace function public.saki_has_admin_permission(p_permission text)
returns boolean
language sql stable security definer set search_path=public
as $$
  select exists (
    select 1 from public.admin_role_permissions arp
    where arp.role = public.saki_current_admin_role()
      and arp.permission = p_permission
  );
$$;

create or replace function public.admin_my_access()
returns jsonb
language sql stable security definer set search_path=public
as $$
  select jsonb_build_object(
    'role', public.saki_current_admin_role(),
    'permissions', coalesce((
      select jsonb_agg(permission order by permission)
      from public.admin_role_permissions
      where role = public.saki_current_admin_role()
    ), '[]'::jsonb)
  );
$$;

create or replace function public.admin_record_audit(
  p_action text,
  p_target_user_id uuid default null,
  p_metadata jsonb default '{}'::jsonb
)
returns void
language plpgsql security definer set search_path=public
as $$
begin
  if public.saki_current_admin_role() = 'user' then
    raise exception 'admin_required';
  end if;
  insert into public.admin_audit_log(actor_id, action, target_user_id, metadata)
  values (auth.uid(), p_action, p_target_user_id, coalesce(p_metadata, '{}'::jsonb));
end;
$$;

create or replace function public.admin_list_audit_log(p_limit integer default 100)
returns table(
  id uuid, action text, target_user_id uuid, metadata jsonb, created_at timestamptz,
  actor_username text, target_username text
)
language plpgsql security definer set search_path=public
as $$
begin
  if not public.saki_has_admin_permission('manage_system')
     and not public.saki_has_admin_permission('manage_users') then
    raise exception 'admin_required';
  end if;
  return query
  select a.id, a.action, a.target_user_id, a.metadata, a.created_at,
    actor.username, target.username
  from public.admin_audit_log a
  join public.profiles actor on actor.id = a.actor_id
  left join public.profiles target on target.id = a.target_user_id
  order by a.created_at desc
  limit greatest(1, least(p_limit, 200));
end;
$$;

create or replace function public.admin_list_users(
  p_query text default null, p_limit integer default 50, p_offset integer default 0
)
returns table(
  id uuid, username text, display_name text, avatar_url text, saki_id bigint,
  vip_level integer, vip_expires_at timestamptz, admin_role text, created_at timestamptz,
  is_banned boolean, ban_expires_at timestamptz
)
language plpgsql security definer set search_path=public
as $$
begin
  if not public.saki_has_admin_permission('view_users') then
    raise exception 'admin_required';
  end if;
  return query
  select p.id,p.username,p.display_name,p.avatar_url,p.saki_id,p.vip_level,p.vip_expires_at,
    case when p.is_super_admin then 'super_admin' else p.admin_role end,
    p.created_at,
    (b.user_id is not null and (b.expires_at is null or b.expires_at > now())),
    b.expires_at
  from public.profiles p
  left join public.app_bans b on b.user_id=p.id
  where coalesce(trim(p_query),'') = ''
    or p.username ilike '%'||trim(p_query)||'%'
    or p.display_name ilike '%'||trim(p_query)||'%'
    or p.saki_id::text = trim(p_query)
  order by p.created_at desc
  limit greatest(1, least(p_limit,100)) offset greatest(0,p_offset);
end;
$$;

create or replace function public.admin_set_user_role(p_user_id uuid, p_role text)
returns void language plpgsql security definer set search_path=public as $$
begin
  if not public.saki_has_admin_permission('manage_user_roles')
     or p_role not in ('user','super_admin','admin','bd','official_host','customer_service') then
    raise exception 'admin_required';
  end if;
  if p_user_id = auth.uid() and p_role <> 'super_admin' then
    raise exception 'cannot_demote_self';
  end if;
  update public.profiles
  set admin_role=p_role,
      is_super_admin=(p_role='super_admin'),
      super_admin_label=case when p_role='super_admin' then 'SUPER ADMIN' else null end,
      updated_at=now()
  where id=p_user_id;
  if not found then raise exception 'user_not_found'; end if;
  insert into public.admin_audit_log(actor_id, action, target_user_id, metadata)
  values (auth.uid(), 'role_changed', p_user_id, jsonb_build_object('role', p_role));
end;
$$;

create or replace function public.saki_admin_dashboard()
returns jsonb language plpgsql security definer set search_path=public as $$
declare result jsonb;
begin
  if not public.saki_has_admin_permission('view_analytics') then raise exception 'admin_required'; end if;
  select jsonb_build_object(
    'role', public.saki_current_admin_role(),
    'users', case when public.saki_has_admin_permission('view_users') then (select count(*) from public.profiles) else 0 end,
    'active_vip', case when public.saki_has_admin_permission('view_users') then (select count(*) from public.profiles where vip_level > 0 and (vip_expires_at is null or vip_expires_at > now())) else 0 end,
    'rooms', case when public.saki_has_admin_permission('manage_rooms') or public.saki_has_admin_permission('manage_official_broadcast') then (select count(*) from public.rooms) else 0 end,
    'messages', case when public.saki_has_admin_permission('manage_reports') then (select count(*) from public.messages) else 0 end,
    'posts', case when public.saki_has_admin_permission('manage_content') then (select count(*) from public.posts) else 0 end,
    'reels', case when public.saki_has_admin_permission('manage_content') then (select count(*) from public.reels) else 0 end,
    'agencies', case when public.saki_has_admin_permission('manage_agencies') then (select count(*) from public.trace_agencies where status = 'active') else 0 end,
    'families', case when public.saki_has_admin_permission('manage_families') then (select count(*) from public.trace_families where status = 'active') else 0 end,
    'bans', case when public.saki_has_admin_permission('ban_users') then (select count(*) from public.app_bans where expires_at is null or expires_at > now()) else 0 end
  ) into result;
  return result;
end; $$;

-- Extend the existing high-impact RPCs to the intended operational roles.
create or replace function public.admin_ban_app(p_saki_id bigint,p_duration interval,p_reason text default null)
returns void language plpgsql security definer set search_path=public as $$
declare target uuid;
begin
  if not public.saki_has_admin_permission('ban_users') then raise exception 'admin_required'; end if;
  select id into target from public.profiles where saki_id=p_saki_id;
  if target is null then raise exception 'user_not_found'; end if;
  if exists(select 1 from public.profiles where id=target and (is_super_admin=true or saki_id=1000)) then raise exception 'protected_super_admin'; end if;
  insert into public.app_bans(user_id,banned_by,expires_at,reason)
  values(target,auth.uid(),case when p_duration is null then null else now()+p_duration end,p_reason)
  on conflict(user_id) do update set banned_by=excluded.banned_by,expires_at=excluded.expires_at,reason=excluded.reason;
  insert into public.admin_audit_log(actor_id, action, target_user_id, metadata)
  values(auth.uid(),'user_banned',target,jsonb_build_object('reason',p_reason,'duration',p_duration::text));
end; $$;

create or replace function public.admin_unban_app(p_user_id uuid)
returns void language plpgsql security definer set search_path=public as $$
begin
  if not public.saki_has_admin_permission('ban_users') then raise exception 'admin_required'; end if;
  delete from public.app_bans where user_id=p_user_id;
  insert into public.admin_audit_log(actor_id, action, target_user_id)
  values(auth.uid(),'user_unbanned',p_user_id);
end; $$;

-- Explicitly prevent unauthenticated RPC access to every administrative function.
do $do$
declare f record;
begin
  for f in
    select p.proname, pg_get_function_identity_arguments(p.oid) as args
    from pg_proc p
    join pg_namespace n on n.oid=p.pronamespace
    where n.nspname='public'
      and (p.proname like 'admin_%' or p.proname in ('saki_admin_dashboard','saki_current_admin_role','saki_has_admin_permission','admin_my_access','is_saki_super_admin'))
  loop
    execute format('revoke all on function public.%I(%s) from anon, public', f.proname, f.args);
    execute format('grant execute on function public.%I(%s) to authenticated', f.proname, f.args);
  end loop;
end $do$;

revoke all on public.admin_role_permissions, public.admin_audit_log from anon, authenticated;

drop policy if exists admin_role_permissions_read on public.admin_role_permissions;
create policy admin_role_permissions_read on public.admin_role_permissions
  for select to authenticated using (public.saki_current_admin_role() <> 'user');

drop policy if exists admin_audit_log_read on public.admin_audit_log;
create policy admin_audit_log_read on public.admin_audit_log
  for select to authenticated using (
    public.saki_has_admin_permission('manage_system')
    or (public.saki_has_admin_permission('manage_users') and actor_id = auth.uid())
  );

comment on table public.admin_role_permissions is 'Database-enforced SAKI RBAC permission matrix.';
comment on table public.admin_audit_log is 'Immutable administrative audit trail for role and moderation actions.';
