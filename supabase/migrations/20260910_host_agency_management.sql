-- Real host-agency management for SAKI.
alter table public.trace_agencies add column if not exists country text not null default '';
create index if not exists trace_agency_members_agency_status_idx on public.trace_agency_members(agency_id, status);

create or replace function public.admin_create_host_agency(
  p_name text, p_owner_saki_id bigint, p_country text
)
returns public.trace_agencies
language plpgsql security definer set search_path=public as $$
declare owner_user uuid; agency public.trace_agencies%rowtype; code text;
begin
  if not public.saki_has_admin_permission('manage_agencies') then raise exception 'admin_required'; end if;
  if nullif(trim(p_name),'') is null or nullif(trim(p_country),'') is null then raise exception 'agency_fields_required'; end if;
  select id into owner_user from public.profiles where saki_id=p_owner_saki_id;
  if owner_user is null then raise exception 'owner_not_found'; end if;
  if exists(select 1 from public.trace_agencies where owner_id=owner_user and status <> 'closed') then raise exception 'owner_already_has_agency'; end if;
  code := 'SAKI-' || upper(substr(md5(random()::text || clock_timestamp()::text),1,8));
  insert into public.trace_agencies(owner_id,name,agent_code,country,status)
  values(owner_user,trim(p_name),code,trim(p_country),'active') returning * into agency;
  insert into public.trace_agency_members(agency_id,user_id,role,status)
  values(agency.id,owner_user,'owner','active')
  on conflict (agency_id,user_id) do update set role='owner',status='active';
  insert into public.admin_audit_log(actor_id,action,target_user_id,metadata)
  values(auth.uid(),'agency_created',owner_user,jsonb_build_object('agency_id',agency.id,'name',agency.name,'country',agency.country,'agent_code',agency.agent_code));
  return agency;
end; $$;

create or replace function public.host_agency_dashboard()
returns jsonb language plpgsql security definer set search_path=public as $$
declare agency public.trace_agencies%rowtype; result jsonb;
begin
  select a.* into agency from public.trace_agencies a where a.owner_id=auth.uid() and a.status <> 'closed' order by a.created_at desc limit 1;
  if agency.id is null then raise exception 'agency_not_found'; end if;
  select jsonb_build_object(
    'agency', jsonb_build_object('id',agency.id,'name',agency.name,'agent_code',agency.agent_code,'country',agency.country,'status',agency.status,'created_at',agency.created_at),
    'host_count',(select count(*) from public.trace_agency_members m where m.agency_id=agency.id and m.role='agent' and m.status='active'),
    'pending_count',(select count(*) from public.trace_agency_members m where m.agency_id=agency.id and m.role='agent' and m.status='pending'),
    'active_rooms',(select count(*) from public.rooms r join public.trace_agency_members m on m.user_id=r.owner_id where m.agency_id=agency.id and m.role='agent' and m.status='active' and r.is_active=true),
    'gift_gold',(select coalesce(sum(g.total_price),0) from public.room_gifts g join public.trace_agency_members m on m.user_id=g.recipient_id where m.agency_id=agency.id and m.role='agent' and m.status='active')
  ) into result;
  return result;
end; $$;

create or replace function public.host_agency_hosts()
returns table(user_id uuid, username text, display_name text, avatar_url text, saki_id bigint, country text, vip_level integer, status text, joined_at timestamptz)
language plpgsql security definer set search_path=public as $$
declare agency_id uuid;
begin
  select id into agency_id from public.trace_agencies where owner_id=auth.uid() and status <> 'closed' order by created_at desc limit 1;
  if agency_id is null then raise exception 'agency_not_found'; end if;
  return query select p.id,p.username,p.display_name,p.avatar_url,p.saki_id,p.country,p.vip_level,m.status,m.joined_at
    from public.trace_agency_members m join public.profiles p on p.id=m.user_id
    where m.agency_id=agency_id and m.role='agent' order by m.joined_at desc;
end; $$;

create or replace function public.host_agency_add_host(p_saki_id bigint)
returns void language plpgsql security definer set search_path=public as $$
declare agency_id uuid; host_id uuid;
begin
  select id into agency_id from public.trace_agencies where owner_id=auth.uid() and status='active' order by created_at desc limit 1;
  if agency_id is null then raise exception 'agency_not_found'; end if;
  select id into host_id from public.profiles where saki_id=p_saki_id;
  if host_id is null then raise exception 'host_not_found'; end if;
  if host_id=auth.uid() then raise exception 'owner_cannot_be_host'; end if;
  if exists(select 1 from public.trace_agency_members where user_id=host_id and status in ('active','pending')) then raise exception 'host_already_assigned'; end if;
  insert into public.trace_agency_members(agency_id,user_id,role,status) values(agency_id,host_id,'agent','active');
  insert into public.admin_audit_log(actor_id,action,target_user_id,metadata) values(auth.uid(),'host_added',host_id,jsonb_build_object('agency_id',agency_id));
end; $$;

create or replace function public.host_agency_set_host_status(p_user_id uuid, p_status text)
returns void language plpgsql security definer set search_path=public as $$
declare agency_id uuid;
begin
  select id into agency_id from public.trace_agencies where owner_id=auth.uid() and status='active' order by created_at desc limit 1;
  if agency_id is null or p_status not in ('active','suspended','left') then raise exception 'agency_required'; end if;
  update public.trace_agency_members set status=p_status where agency_id=agency_id and user_id=p_user_id and role='agent';
  if not found then raise exception 'host_not_found'; end if;
  insert into public.admin_audit_log(actor_id,action,target_user_id,metadata) values(auth.uid(),'host_status_changed',p_user_id,jsonb_build_object('agency_id',agency_id,'status',p_status));
end; $$;

create or replace function public.admin_list_agencies()
returns table(id uuid,name text,agent_code text,country text,status text,created_at timestamptz,owner_id uuid,owner_username text,owner_saki_id bigint,host_count bigint)
language sql security definer set search_path=public as $$
  select a.id,a.name,a.agent_code,a.country,a.status,a.created_at,a.owner_id,p.username,p.saki_id,
    (select count(*) from public.trace_agency_members m where m.agency_id=a.id and m.role='agent' and m.status='active')
  from public.trace_agencies a join public.profiles p on p.id=a.owner_id
  where public.saki_has_admin_permission('manage_agencies') order by a.created_at desc limit 200;
$$;

revoke all on function public.admin_create_host_agency(text,bigint,text),public.host_agency_dashboard(),public.host_agency_hosts(),public.host_agency_add_host(bigint),public.host_agency_set_host_status(uuid,text),public.admin_list_agencies() from anon,public;
grant execute on function public.admin_create_host_agency(text,bigint,text),public.host_agency_dashboard(),public.host_agency_hosts(),public.host_agency_add_host(bigint),public.host_agency_set_host_status(uuid,text),public.admin_list_agencies() to authenticated;

-- Scope-safe replacements for functions that use an agency id variable.
create or replace function public.host_agency_hosts()
returns table(user_id uuid, username text, display_name text, avatar_url text, saki_id bigint, country text, vip_level integer, status text, joined_at timestamptz)
language plpgsql security definer set search_path=public as $$
declare v_agency_id uuid;
begin
  select a.id into v_agency_id from public.trace_agencies a where a.owner_id=auth.uid() and a.status <> 'closed' order by a.created_at desc limit 1;
  if v_agency_id is null then raise exception 'agency_not_found'; end if;
  return query select p.id,p.username,p.display_name,p.avatar_url,p.saki_id,p.country,p.vip_level,m.status,m.joined_at
    from public.trace_agency_members m join public.profiles p on p.id=m.user_id
    where m.agency_id=v_agency_id and m.role='agent' order by m.joined_at desc;
end; $$;

create or replace function public.host_agency_set_host_status(p_user_id uuid, p_status text)
returns void language plpgsql security definer set search_path=public as $$
declare v_agency_id uuid;
begin
  select a.id into v_agency_id from public.trace_agencies a where a.owner_id=auth.uid() and a.status='active' order by a.created_at desc limit 1;
  if v_agency_id is null or p_status not in ('active','suspended','left') then raise exception 'agency_required'; end if;
  update public.trace_agency_members m set status=p_status where m.agency_id=v_agency_id and m.user_id=p_user_id and m.role='agent';
  if not found then raise exception 'host_not_found'; end if;
  insert into public.admin_audit_log(actor_id,action,target_user_id,metadata) values(auth.uid(),'host_status_changed',p_user_id,jsonb_build_object('agency_id',v_agency_id,'status',p_status));
end; $$;
