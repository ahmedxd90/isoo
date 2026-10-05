-- Real profile cover gallery with server-enforced ownership and ordering.
create table if not exists public.profile_cover_images (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references public.profiles(id) on delete cascade,
  image_url text not null,
  storage_path text not null,
  sort_order smallint not null default 0 check (sort_order between 0 and 4),
  created_at timestamptz not null default now()
);

create index if not exists profile_cover_images_user_order_idx
  on public.profile_cover_images(user_id, sort_order, created_at);

alter table public.profile_cover_images enable row level security;

drop policy if exists profile_cover_images_select on public.profile_cover_images;
create policy profile_cover_images_select
  on public.profile_cover_images for select
  to authenticated
  using (true);

drop policy if exists profile_cover_images_insert on public.profile_cover_images;
create policy profile_cover_images_insert
  on public.profile_cover_images for insert
  to authenticated
  with check (auth.uid() = user_id);

drop policy if exists profile_cover_images_update on public.profile_cover_images;
create policy profile_cover_images_update
  on public.profile_cover_images for update
  to authenticated
  using (auth.uid() = user_id)
  with check (auth.uid() = user_id);

drop policy if exists profile_cover_images_delete on public.profile_cover_images;
create policy profile_cover_images_delete
  on public.profile_cover_images for delete
  to authenticated
  using (auth.uid() = user_id);

-- Enforce the product rule at database level: regular users may keep one
-- cover, while active VIP7+ users may keep up to five covers.
create or replace function public.enforce_profile_cover_limit()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  current_vip integer;
  current_expiry timestamptz;
  cover_count integer;
begin
  select coalesce(vip_level, 0), vip_expires_at
    into current_vip, current_expiry
    from public.profiles
   where id = new.user_id;

  if current_vip >= 7 and (current_expiry is null or current_expiry > now()) then
    select count(*) into cover_count
      from public.profile_cover_images
     where user_id = new.user_id
       and id <> new.id;
    if cover_count >= 5 then
      raise exception 'profile_cover_limit_vip7';
    end if;
  else
    select count(*) into cover_count
      from public.profile_cover_images
     where user_id = new.user_id
       and id <> new.id;
    if cover_count >= 1 then
      raise exception 'profile_cover_limit_one';
    end if;
  end if;

  return new;
end;
$$;

drop trigger if exists profile_cover_limit on public.profile_cover_images;
create trigger profile_cover_limit
before insert or update on public.profile_cover_images
for each row execute function public.enforce_profile_cover_limit();

-- Keep the ordering range unique per user so the UI can safely reorder covers.
create unique index if not exists profile_cover_images_user_order_key
  on public.profile_cover_images(user_id, sort_order);

grant select, insert, update, delete on public.profile_cover_images to authenticated;
