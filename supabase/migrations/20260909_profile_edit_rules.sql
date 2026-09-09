alter table public.profiles
  add column if not exists country_updated_at timestamptz;

update public.profiles
set country_updated_at = updated_at
where country is not null and country_updated_at is null;

create or replace function public.enforce_profile_edit_rules()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  if new.country is distinct from old.country then
    if old.country_updated_at is not null
       and old.country_updated_at > now() - interval '30 days' then
      raise exception 'country_change_cooldown';
    end if;
    new.country_updated_at = now();
  end if;

  if new.avatar_url is distinct from old.avatar_url
     and lower(coalesce(new.avatar_url, '')) ~ '\\.gif($|[?])' then
    if coalesce(new.vip_level, 0) < 7
       or (new.vip_expires_at is not null and new.vip_expires_at <= now()) then
      raise exception 'vip7_required_for_gif';
    end if;
  end if;

  return new;
end;
$$;

drop trigger if exists profile_edit_rules on public.profiles;
create trigger profile_edit_rules
before update on public.profiles
for each row execute function public.enforce_profile_edit_rules();
