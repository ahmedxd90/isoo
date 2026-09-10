-- Real agency deletion for the administration panel.
create or replace function public.admin_delete_host_agency(p_agency_id uuid)
returns void
language plpgsql security definer set search_path=public as $$
declare v_owner_id uuid; v_name text;
begin
  if not public.saki_has_admin_permission('manage_agencies') then
    raise exception 'admin_required';
  end if;
  select owner_id,name into v_owner_id,v_name
  from public.trace_agencies
  where id=p_agency_id
  for update;
  if p_agency_id is null or v_owner_id is null then
    raise exception 'agency_not_found';
  end if;

  -- This table intentionally uses RESTRICT to prevent deleting unsettled money.
  -- An admin deletion is explicit and removes the pending/old request records first.
  delete from public.host_agency_withdrawal_requests where agency_id=p_agency_id;
  insert into public.admin_audit_log(actor_id,action,target_user_id,metadata)
  values(auth.uid(),'agency_deleted',v_owner_id,jsonb_build_object('agency_id',p_agency_id,'name',v_name));
  delete from public.notifications where data->>'agency_id'=p_agency_id::text;
  delete from public.trace_agencies where id=p_agency_id;
end; $$;

revoke all on function public.admin_delete_host_agency(uuid) from anon,public;
grant execute on function public.admin_delete_host_agency(uuid) to authenticated;
