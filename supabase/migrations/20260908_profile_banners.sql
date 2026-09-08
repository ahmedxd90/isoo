alter table public.room_banners
  add column if not exists target_type text not null default 'room',
  add column if not exists target_user_id uuid references public.profiles(id) on delete set null,
  add column if not exists target_room_id uuid references public.rooms(id) on delete set null,
  add column if not exists starts_at timestamptz,
  add column if not exists ends_at timestamptz;

alter table public.room_banners drop constraint if exists room_banners_target_type_check;
alter table public.room_banners add constraint room_banners_target_type_check
  check (target_type in ('room','profile','none'));

create index if not exists room_banners_active_window_idx
  on public.room_banners(is_active, starts_at, ends_at, sort_order);

create or replace function public.is_banner_visible(p_banner public.room_banners)
returns boolean
language sql stable
as $$
  select p_banner.is_active
    and (p_banner.starts_at is null or p_banner.starts_at <= now())
    and (p_banner.ends_at is null or p_banner.ends_at > now());
$$;

create or replace function public.resolve_banner_profile(p_saki_id bigint)
returns uuid
language sql stable security definer set search_path = public
as $$
  select id from public.profiles where saki_id = p_saki_id limit 1;
$$;

create or replace function public.resolve_banner_room(p_room_code text)
returns uuid
language sql stable security definer set search_path = public
as $$
  select id from public.rooms
  where is_active = true and (room_id::text = p_room_code or id::text = p_room_code)
  limit 1;
$$;

-- Keep the existing table name for compatibility with the room banner system.
drop policy if exists room_banners_read on public.room_banners;
create policy room_banners_read on public.room_banners
  for select to authenticated using (public.is_banner_visible(room_banners) or public.is_saki_super_admin());
drop policy if exists room_banners_admin_write on public.room_banners;
create policy room_banners_admin_write on public.room_banners
  for all to authenticated
  using (public.is_saki_super_admin())
  with check (public.is_saki_super_admin());

insert into storage.buckets (id, name, public)
values ('banners', 'banners', true)
on conflict (id) do update set public = true;

drop policy if exists banners_public_read on storage.objects;
create policy banners_public_read on storage.objects
  for select using (bucket_id = 'banners');
drop policy if exists banners_admin_insert on storage.objects;
create policy banners_admin_insert on storage.objects
  for insert to authenticated with check (bucket_id = 'banners' and public.is_saki_super_admin());
drop policy if exists banners_admin_update on storage.objects;
create policy banners_admin_update on storage.objects
  for update to authenticated using (bucket_id = 'banners' and public.is_saki_super_admin()) with check (bucket_id = 'banners' and public.is_saki_super_admin());
drop policy if exists banners_admin_delete on storage.objects;
create policy banners_admin_delete on storage.objects
  for delete to authenticated using (bucket_id = 'banners' and public.is_saki_super_admin());

grant execute on function public.resolve_banner_profile(bigint) to authenticated;
grant execute on function public.resolve_banner_room(text) to authenticated;
