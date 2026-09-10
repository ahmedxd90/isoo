-- Make agency invitations visible, attributable, and stateful in system notifications.
create or replace function public.host_agency_invite_host(p_saki_id bigint)
returns uuid language plpgsql security definer set search_path=public as $$
declare v_agency public.trace_agencies%rowtype; v_host uuid; v_invite uuid; v_agent_name text;
begin
  select a.* into v_agency from public.trace_agencies a where a.owner_id=auth.uid() and a.status='active' order by a.created_at desc limit 1;
  if v_agency.id is null then raise exception 'agency_not_found'; end if;
  select id into v_host from public.profiles where saki_id=p_saki_id;
  if v_host is null then raise exception 'host_not_found'; end if;
  if v_host=auth.uid() then raise exception 'owner_cannot_be_host'; end if;
  if exists(select 1 from public.trace_agency_members where user_id=v_host and status='active') then raise exception 'host_already_assigned'; end if;
  insert into public.trace_agency_join_requests(agency_id,user_id,status)
    values(v_agency.id,v_host,'pending')
    on conflict(agency_id,user_id,status) do update set created_at=now()
    returning id into v_invite;
  select coalesce(nullif(display_name,''),username,'الوكيل') into v_agent_name from public.profiles where id=auth.uid();
  insert into public.notifications(user_id,actor_id,type,entity_id,is_read,data)
    values(v_host,auth.uid(),'agency_invite',v_invite,false,jsonb_build_object(
      'agency_id',v_agency.id,'agency_name',v_agency.name,'agent_name',v_agent_name,'response','pending'));
  return v_invite;
end; $$;

create or replace function public.host_agency_accept_invite(p_invite_id uuid)
returns void language plpgsql security definer set search_path=public as $$
declare v_request public.trace_agency_join_requests%rowtype; v_agency public.trace_agencies%rowtype;
begin
  select * into v_request from public.trace_agency_join_requests where id=p_invite_id and user_id=auth.uid() and status='pending' for update;
  if v_request.id is null then raise exception 'invite_not_found'; end if;
  select * into v_agency from public.trace_agencies where id=v_request.agency_id and status='active';
  if v_agency.id is null then raise exception 'agency_not_active'; end if;
  if exists(select 1 from public.trace_agency_members where user_id=auth.uid() and status='active') then raise exception 'host_already_assigned'; end if;
  update public.trace_agency_join_requests set status='approved',reviewed_at=now() where id=v_request.id;
  insert into public.trace_agency_members(agency_id,user_id,role,status) values(v_agency.id,auth.uid(),'agent','active') on conflict(agency_id,user_id) do update set role='agent',status='active';
  update public.notifications set is_read=true,data=coalesce(data,'{}'::jsonb)||jsonb_build_object('response','accepted') where entity_id=p_invite_id and user_id=auth.uid() and type='agency_invite';
end; $$;

create or replace function public.host_agency_decline_invite(p_invite_id uuid)
returns void language plpgsql security definer set search_path=public as $$
begin
  update public.trace_agency_join_requests set status='rejected',reviewed_at=now() where id=p_invite_id and user_id=auth.uid() and status='pending';
  if not found then raise exception 'invite_not_found'; end if;
  update public.notifications set is_read=true,data=coalesce(data,'{}'::jsonb)||jsonb_build_object('response','declined') where entity_id=p_invite_id and user_id=auth.uid() and type='agency_invite';
end; $$;

revoke all on function public.host_agency_invite_host(bigint),public.host_agency_accept_invite(uuid),public.host_agency_decline_invite(uuid) from anon,public;
grant execute on function public.host_agency_invite_host(bigint),public.host_agency_accept_invite(uuid),public.host_agency_decline_invite(uuid) to authenticated;
