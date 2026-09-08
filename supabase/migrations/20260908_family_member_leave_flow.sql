create or replace function public.leave_family(p_family_id uuid)
returns void language plpgsql security definer set search_path=public as $$
begin
  if exists(select 1 from public.family_members where family_id=p_family_id and user_id=auth.uid() and role='owner' and status='active') then raise exception 'owner_cannot_leave'; end if;
  update public.family_members set status='left',left_at=now() where family_id=p_family_id and user_id=auth.uid() and status='active';
  if not found then raise exception 'family_membership_not_found'; end if;
end; $$;
grant execute on function public.leave_family(uuid) to authenticated;
