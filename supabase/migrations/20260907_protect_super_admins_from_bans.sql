create or replace function public.prevent_super_admin_ban()
returns trigger
language plpgsql security definer set search_path = public
as $$
begin
  if exists (
    select 1 from public.profiles p
    where p.id = new.user_id and p.is_super_admin = true
  ) then
    raise exception 'protected_super_admin';
  end if;
  return new;
end;
$$;

drop trigger if exists protect_super_admin_app_ban on public.app_bans;
create trigger protect_super_admin_app_ban
before insert or update on public.app_bans
for each row execute function public.prevent_super_admin_ban();

drop trigger if exists protect_super_admin_room_ban on public.room_bans;
create trigger protect_super_admin_room_ban
before insert or update on public.room_bans
for each row execute function public.prevent_super_admin_ban();

create or replace function public.admin_ban_app(
  p_saki_id bigint,
  p_duration interval,
  p_reason text default null
)
returns void language plpgsql security definer set search_path = public
as $$
declare
  target uuid;
  protected boolean;
begin
  if not public.is_saki_super_admin() then raise exception 'admin_required'; end if;
  select id, is_super_admin into target, protected
  from public.profiles where saki_id = p_saki_id;
  if target is null then raise exception 'user_not_found'; end if;
  if protected then raise exception 'protected_super_admin'; end if;
  insert into public.app_bans(user_id,banned_by,expires_at,reason)
  values(target,auth.uid(),case when p_duration is null then null else now()+p_duration end,p_reason)
  on conflict(user_id) do update set
    banned_by=excluded.banned_by,
    expires_at=excluded.expires_at,
    reason=excluded.reason;
end;
$$;

delete from public.app_bans b
using public.profiles p
where b.user_id = p.id and p.saki_id = 1000;
