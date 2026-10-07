-- Allow the existing super-admin-only assignment RPC to set VIP 11.
-- No account rows are changed by this migration.
create or replace function public.admin_set_vip(
  p_saki_id bigint,
  p_level integer,
  p_days integer
)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  target uuid;
begin
  if not public.is_saki_super_admin()
     or p_level < 0
     or p_level > 11
     or p_days < 0 then
    raise exception 'admin_required';
  end if;

  select p.id
    into target
    from public.profiles as p
   where p.saki_id = p_saki_id;

  if target is null then
    raise exception 'user_not_found';
  end if;

  update public.profiles as p
     set vip_level = p_level,
         vip_expires_at = case
           when p_level = 0 then null
           else now() + (p_days || ' days')::interval
         end,
         updated_at = now()
   where p.id = target;

  update public.saki_account_modules as m
     set vip_level = p_level,
         vip_label = case
           when p_level = 0 then null
           else 'VIP ' || p_level
         end,
         updated_at = now()
   where m.user_id = target;
end;
$$;

revoke all on function public.admin_set_vip(bigint, integer, integer) from public;
grant execute on function public.admin_set_vip(bigint, integer, integer) to authenticated;
