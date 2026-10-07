-- VIP privacy entitlements: server-enforced feature flags.
alter table public.profiles
  add column if not exists hide_online boolean not null default false,
  add column if not exists hide_country boolean not null default false,
  add column if not exists animated_avatar_enabled boolean not null default false,
  add column if not exists identity_hidden boolean not null default false;

create or replace function public.saki_active_vip_level(p_user_id uuid)
returns integer
language sql
stable
security definer
set search_path = public
as $$
  select case
    when p.vip_expires_at is not null and p.vip_expires_at > now()
      then greatest(coalesce(p.vip_level, 0), 0)
    else 0
  end
  from public.profiles p
  where p.id = p_user_id
$$;

create or replace function public.saki_profile_privacy_settings()
returns jsonb
language sql
stable
security definer
set search_path = public
as $$
  select jsonb_build_object(
    'vip_level', public.saki_active_vip_level(auth.uid()),
    'hide_online', coalesce(p.hide_online, false),
    'hide_country', coalesce(p.hide_country, false),
    'animated_avatar_enabled', coalesce(p.animated_avatar_enabled, false),
    'identity_hidden', coalesce(p.identity_hidden, false)
  )
  from public.profiles p
  where p.id = auth.uid()
$$;

create or replace function public.saki_set_profile_privacy_setting(
  p_setting text,
  p_enabled boolean
)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  required_level integer;
  active_level integer;
  result jsonb;
begin
  if auth.uid() is null then raise exception 'not_authenticated'; end if;
  required_level := case p_setting
    when 'hide_online' then 4
    when 'hide_country' then 5
    when 'animated_avatar_enabled' then 8
    when 'identity_hidden' then 11
    else 0
  end;
  if required_level = 0 then raise exception 'invalid_privacy_setting'; end if;
  active_level := public.saki_active_vip_level(auth.uid());
  if p_enabled and active_level < required_level then
    raise exception 'vip_level_required:%', required_level;
  end if;
  execute format(
    'update public.profiles set %I = $1, updated_at = now() where id = $2',
    p_setting
  ) using p_enabled, auth.uid();
  select public.saki_profile_privacy_settings() into result;
  return result;
end;
$$;

create or replace function public.saki_public_profile(p_user_id uuid)
returns jsonb
language plpgsql
stable
security definer
set search_path = public
as $$
declare
  p public.profiles;
  hidden boolean;
  result jsonb;
begin
  select * into p from public.profiles where id = p_user_id;
  if not found then return null; end if;
  hidden := coalesce(p.identity_hidden, false)
    and public.saki_active_vip_level(p.id) >= 11
    and auth.uid() is distinct from p.id;
  if not hidden then return to_jsonb(p); end if;
  result := jsonb_build_object(
    'id', p.id,
    'username', 'اسم مخفي',
    'display_name', 'مستخدم مخفي',
    'saki_id', null,
    'avatar_url', null,
    'bio', null,
    'country', null,
    'country_code', '',
    'gender', null,
    'created_at', null,
    'vip_level', 0,
    'vip_expires_at', null,
    'wealth_xp', 0,
    'wealth_level', 0,
    'is_super_admin', false,
    'admin_role', 'user',
    'identity_hidden', true,
    'is_private_identity', true
  );
  return result;
end;
$$;

revoke all on function public.saki_active_vip_level(uuid) from public;
revoke all on function public.saki_profile_privacy_settings() from public;
revoke all on function public.saki_set_profile_privacy_setting(text, boolean) from public;
revoke all on function public.saki_public_profile(uuid) from public;
grant execute on function public.saki_active_vip_level(uuid) to authenticated;
grant execute on function public.saki_profile_privacy_settings() to authenticated;
grant execute on function public.saki_set_profile_privacy_setting(text, boolean) to authenticated;
grant execute on function public.saki_public_profile(uuid) to authenticated;
