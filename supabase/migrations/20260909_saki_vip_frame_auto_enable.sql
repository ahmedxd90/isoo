create or replace function public.saki_vip_auto_enable_frame()
returns trigger language plpgsql security definer set search_path=public as $$
begin
  if coalesce(new.vip_level, 0) > coalesce(old.vip_level, 0)
     and (new.vip_expires_at is null or new.vip_expires_at > now()) then
    new.vip_frame_enabled := true;
  end if;
  return new;
end; $$;

drop trigger if exists profiles_vip_auto_enable_frame on public.profiles;
create trigger profiles_vip_auto_enable_frame
before update of vip_level, vip_expires_at on public.profiles
for each row execute function public.saki_vip_auto_enable_frame();
