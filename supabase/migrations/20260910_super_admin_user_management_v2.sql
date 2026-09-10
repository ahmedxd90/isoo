-- Complete Super Admin user management: roles, searchable user list and safe admin actions.
alter table public.profiles add column if not exists admin_role text not null default 'user';
alter table public.profiles drop constraint if exists profiles_admin_role_check;
alter table public.profiles add constraint profiles_admin_role_check
  check (admin_role in ('user','super_admin','admin','bd','official_host','customer_service'));
create index if not exists profiles_admin_role_idx on public.profiles(admin_role);

create or replace function public.admin_list_users(p_query text default null, p_limit integer default 50, p_offset integer default 0)
returns table(
  id uuid, username text, display_name text, avatar_url text, saki_id bigint,
  vip_level integer, vip_expires_at timestamptz, admin_role text, created_at timestamptz,
  is_banned boolean, ban_expires_at timestamptz
)
language plpgsql security definer set search_path=public as $$
begin
  if not public.is_saki_super_admin() then raise exception 'admin_required'; end if;
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
end; $$;

create or replace function public.admin_set_user_role(p_user_id uuid, p_role text)
returns void language plpgsql security definer set search_path=public as $$
begin
  if not public.is_saki_super_admin() or p_role not in ('user','super_admin','admin','bd','official_host','customer_service') then raise exception 'admin_required'; end if;
  if p_user_id = auth.uid() and p_role <> 'super_admin' then raise exception 'cannot_demote_self'; end if;
  update public.profiles set admin_role=p_role, is_super_admin=(p_role='super_admin'), super_admin_label=case when p_role='super_admin' then 'SUPER ADMIN' else null end, updated_at=now() where id=p_user_id;
  if not found then raise exception 'user_not_found'; end if;
end; $$;

create or replace function public.admin_update_user_profile(p_user_id uuid, p_new_saki_id bigint default null)
returns void language plpgsql security definer set search_path=public as $$
begin
  if not public.is_saki_super_admin() or p_new_saki_id is null or p_new_saki_id < 1 then raise exception 'admin_required'; end if;
  if exists(select 1 from public.profiles where saki_id=p_new_saki_id and id<>p_user_id) then raise exception 'saki_id_taken'; end if;
  update public.profiles set saki_id=p_new_saki_id,updated_at=now() where id=p_user_id;
  if not found then raise exception 'user_not_found'; end if;
end; $$;

revoke all on function public.admin_list_users(text,integer,integer), public.admin_set_user_role(uuid,text), public.admin_update_user_profile(uuid,bigint) from public;
grant execute on function public.admin_list_users(text,integer,integer), public.admin_set_user_role(uuid,text), public.admin_update_user_profile(uuid,bigint) to authenticated;
