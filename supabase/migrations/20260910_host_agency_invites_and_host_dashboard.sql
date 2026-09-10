-- Host membership, invitation notifications, host dashboard and payout contract.

create or replace function public.is_host_agency_member(p_user_id uuid default auth.uid())
returns boolean language sql stable security definer set search_path=public as $$
  select exists (select 1 from public.trace_agency_members m where m.user_id=p_user_id and m.status='active' and m.role in ('owner','agent'));
$$;

create or replace function public.is_host_agency_owner(p_user_id uuid default auth.uid())
returns boolean language sql stable security definer set search_path=public as $$
  select exists (select 1 from public.trace_agencies a where a.owner_id=p_user_id and a.status='active');
$$;

create or replace function public.host_agency_diamond_usd_value(p_diamonds bigint)
returns numeric(12,2) language plpgsql immutable as $$
declare v_usd numeric(12,2) := 0;
begin
  if p_diamonds is null or p_diamonds < 0 then return 0; end if;
  if p_diamonds >= 2000000 then
    v_usd := floor(p_diamonds / 2000000)::numeric * 102 + case when mod(p_diamonds,2000000) >= 1000000 then 52 when mod(p_diamonds,2000000) >= 500000 then 26 when mod(p_diamonds,2000000) >= 250000 then 13 else 0 end;
  elsif p_diamonds >= 1000000 then
    v_usd := floor(p_diamonds / 1000000)::numeric * 52 + case when mod(p_diamonds,1000000) >= 500000 then 26 when mod(p_diamonds,1000000) >= 250000 then 13 else 0 end;
  elsif p_diamonds >= 500000 then
    v_usd := floor(p_diamonds / 500000)::numeric * 26 + case when mod(p_diamonds,500000) >= 250000 then 13 else 0 end;
  elsif p_diamonds >= 250000 then
    v_usd := floor(p_diamonds / 250000)::numeric * 13;
  end if;
  return v_usd;
end; $$;

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
  insert into public.trace_agency_join_requests(agency_id,user_id,status) values(v_agency.id,v_host,'pending') on conflict(agency_id,user_id,status) do update set created_at=now() returning id into v_invite;
  select coalesce(display_name,username) into v_agent_name from public.profiles where id=auth.uid();
  insert into public.notifications(user_id,actor_id,type,entity_id,is_read,data) values(v_host,auth.uid(),'agency_invite',v_invite,false,jsonb_build_object('agency_id',v_agency.id,'agency_name',v_agency.name,'agent_name',v_agent_name));
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
  update public.notifications set is_read=true where entity_id=p_invite_id and user_id=auth.uid() and type='agency_invite';
end; $$;

create or replace function public.host_agency_decline_invite(p_invite_id uuid)
returns void language plpgsql security definer set search_path=public as $$
begin
  update public.trace_agency_join_requests set status='rejected',reviewed_at=now() where id=p_invite_id and user_id=auth.uid() and status='pending';
  if not found then raise exception 'invite_not_found'; end if;
  update public.notifications set is_read=true where entity_id=p_invite_id and user_id=auth.uid() and type='agency_invite';
end; $$;

create or replace function public.host_agency_cancel_invite(p_invite_id uuid)
returns void language plpgsql security definer set search_path=public as $$
begin
  if not exists(select 1 from public.trace_agency_join_requests r join public.trace_agencies a on a.id=r.agency_id where r.id=p_invite_id and a.owner_id=auth.uid() and r.status='pending') then raise exception 'invite_not_found'; end if;
  update public.trace_agency_join_requests set status='cancelled',reviewed_at=now() where id=p_invite_id;
  update public.notifications set is_read=true where entity_id=p_invite_id and type='agency_invite';
end; $$;

create or replace function public.host_agency_remove_host(p_user_id uuid)
returns void language plpgsql security definer set search_path=public as $$
declare v_agency_id uuid;
begin
  select id into v_agency_id from public.trace_agencies where owner_id=auth.uid() and status='active' order by created_at desc limit 1;
  if v_agency_id is null then raise exception 'agency_not_found'; end if;
  update public.trace_agency_members set status='left' where agency_id=v_agency_id and user_id=p_user_id and role='agent';
  if not found then raise exception 'host_not_found'; end if;
end; $$;

create or replace function public.host_agency_host_dashboard()
returns jsonb language plpgsql security definer set search_path=public as $$
declare v_agency public.trace_agencies%rowtype; v_member public.trace_agency_members%rowtype; v_diamonds bigint; v_usd numeric(12,2);
begin
  select m.* into v_member from public.trace_agency_members m where m.user_id=auth.uid() and m.role='agent' and m.status='active' limit 1;
  if v_member.agency_id is null then raise exception 'host_agency_not_found'; end if;
  select * into v_agency from public.trace_agencies where id=v_member.agency_id and status='active';
  select coalesce(diamonds,0) into v_diamonds from public.saki_account_modules where user_id=auth.uid();
  v_usd := public.host_agency_diamond_usd_value(v_diamonds);
  return jsonb_build_object('agency',jsonb_build_object('id',v_agency.id,'name',v_agency.name,'country',v_agency.country,'agent_code',v_agency.agent_code),'diamonds',v_diamonds,'usd_amount',v_usd,'rates',jsonb_build_array(jsonb_build_object('diamonds',250000,'usd',13),jsonb_build_object('diamonds',500000,'usd',26),jsonb_build_object('diamonds',1000000,'usd',52),jsonb_build_object('diamonds',2000000,'usd',102)));
end; $$;

revoke all on function public.is_host_agency_member(uuid),public.is_host_agency_owner(uuid),public.host_agency_invite_host(bigint),public.host_agency_accept_invite(uuid),public.host_agency_decline_invite(uuid),public.host_agency_cancel_invite(uuid),public.host_agency_remove_host(uuid),public.host_agency_host_dashboard() from anon,public;
grant execute on function public.is_host_agency_member(uuid),public.is_host_agency_owner(uuid),public.host_agency_invite_host(bigint),public.host_agency_accept_invite(uuid),public.host_agency_decline_invite(uuid),public.host_agency_cancel_invite(uuid),public.host_agency_remove_host(uuid),public.host_agency_host_dashboard() to authenticated;
