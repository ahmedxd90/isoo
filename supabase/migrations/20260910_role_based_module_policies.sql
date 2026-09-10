-- Extend RBAC to existing operational modules without changing their data model.

drop policy if exists trace_agencies_admin on public.trace_agencies;
create policy trace_agencies_admin on public.trace_agencies for all to authenticated
  using (public.saki_has_admin_permission('manage_agencies'))
  with check (public.saki_has_admin_permission('manage_agencies'));

drop policy if exists trace_agency_members_admin on public.trace_agency_members;
create policy trace_agency_members_admin on public.trace_agency_members for all to authenticated
  using (public.saki_has_admin_permission('manage_agencies'))
  with check (public.saki_has_admin_permission('manage_agencies'));

drop policy if exists trace_agency_requests_admin on public.trace_agency_join_requests;
create policy trace_agency_requests_admin on public.trace_agency_join_requests for all to authenticated
  using (public.saki_has_admin_permission('manage_agencies'))
  with check (public.saki_has_admin_permission('manage_agencies'));

drop policy if exists trace_families_admin on public.trace_families;
create policy trace_families_admin on public.trace_families for all to authenticated
  using (public.saki_has_admin_permission('manage_families'))
  with check (public.saki_has_admin_permission('manage_families'));

drop policy if exists trace_family_members_admin on public.trace_family_members;
create policy trace_family_members_admin on public.trace_family_members for all to authenticated
  using (public.saki_has_admin_permission('manage_families'))
  with check (public.saki_has_admin_permission('manage_families'));

drop policy if exists user_reports_admin_select on public.user_reports;
create policy user_reports_admin_select on public.user_reports for select to authenticated
  using (auth.uid() = reporter_id or public.saki_has_admin_permission('manage_reports') or public.saki_has_admin_permission('support_users'));

drop policy if exists user_reports_admin_update on public.user_reports;
create policy user_reports_admin_update on public.user_reports for update to authenticated
  using (public.saki_has_admin_permission('manage_reports'))
  with check (public.saki_has_admin_permission('manage_reports'));

create or replace function public.admin_set_agency_status(p_agency_id uuid, p_status text)
returns void language plpgsql security definer set search_path=public as $$
begin
  if not public.saki_has_admin_permission('manage_agencies')
     or p_status not in ('active','suspended','closed') then
    raise exception 'admin_required';
  end if;
  update public.trace_agencies set status=p_status where id=p_agency_id;
  insert into public.admin_audit_log(actor_id, action, metadata)
  values (auth.uid(), 'agency_status_changed', jsonb_build_object('agency_id', p_agency_id, 'status', p_status));
end;
$$;

create or replace function public.admin_set_family_status(p_family_id uuid, p_status text)
returns void language plpgsql security definer set search_path=public as $$
begin
  if not public.saki_has_admin_permission('manage_families')
     or p_status not in ('active','suspended','closed') then
    raise exception 'admin_required';
  end if;
  update public.trace_families set status=p_status where id=p_family_id;
  insert into public.admin_audit_log(actor_id, action, metadata)
  values (auth.uid(), 'family_status_changed', jsonb_build_object('family_id', p_family_id, 'status', p_status));
end;
$$;

revoke all on function public.admin_set_agency_status(uuid,text), public.admin_set_family_status(uuid,text) from anon, public;
grant execute on function public.admin_set_agency_status(uuid,text), public.admin_set_family_status(uuid,text) to authenticated;
