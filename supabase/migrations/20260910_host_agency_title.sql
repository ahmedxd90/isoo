create or replace function public.is_host_agency_owner(p_user_id uuid default auth.uid())
returns boolean
language sql stable security definer set search_path=public as $$
  select exists (
    select 1 from public.trace_agencies a
    where a.owner_id = p_user_id and a.status = 'active'
  );
$$;
revoke all on function public.is_host_agency_owner(uuid) from anon, public;
grant execute on function public.is_host_agency_owner(uuid) to authenticated;
