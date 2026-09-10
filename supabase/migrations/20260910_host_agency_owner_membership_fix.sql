-- Owners are agency members too; this makes the agency module visible to owners.
create or replace function public.is_host_agency_member(p_user_id uuid default auth.uid())
returns boolean language sql stable security definer set search_path=public as $$
  select exists(
    select 1
    from public.trace_agency_members m
    join public.trace_agencies a on a.id=m.agency_id
    where m.user_id=p_user_id
      and m.role in ('owner','agent')
      and m.status='active'
      and a.status='active'
  );
$$;
revoke all on function public.is_host_agency_member(uuid) from anon,public;
grant execute on function public.is_host_agency_member(uuid) to authenticated;
