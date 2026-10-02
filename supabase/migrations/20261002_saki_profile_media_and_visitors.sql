-- Allow each authenticated user to attach media only to their own post and
-- only from their own storage folder. The app stores files as
-- <auth.uid>/<post_id>/<index>.<extension>.
drop policy if exists saki_post_media_insert on public.post_media;
create policy saki_post_media_insert
  on public.post_media
  for insert to authenticated
  with check (
    exists (
      select 1
      from public.posts p
      where p.id = post_media.post_id
        and p.author_id = auth.uid()
    )
    and post_media.storage_path like (
      auth.uid()::text || '/' || post_media.post_id::text || '/%'
    )
  );

-- Count distinct users who have opened a profile, without exposing the
-- visitor list to clients. Repeated visits update last_visited_at, not count.
create table if not exists public.profile_visits (
  profile_id uuid not null references public.profiles(id) on delete cascade,
  visitor_id uuid not null references public.profiles(id) on delete cascade,
  last_visited_at timestamptz not null default pg_catalog.now(),
  primary key (profile_id, visitor_id),
  constraint profile_visits_no_self_visit check (profile_id <> visitor_id)
);

alter table public.profile_visits enable row level security;
revoke all on table public.profile_visits from anon, authenticated;

create or replace function public.record_profile_visit(p_profile_id uuid)
returns void
language plpgsql
security definer
set search_path = ''
as $$
begin
  if auth.uid() is null then
    raise exception 'not_authenticated';
  end if;
  if p_profile_id is null or p_profile_id = auth.uid() then
    return;
  end if;
  if not exists (
    select 1 from public.profiles p where p.id = p_profile_id
  ) then
    return;
  end if;

  insert into public.profile_visits(profile_id, visitor_id, last_visited_at)
  values (p_profile_id, auth.uid(), pg_catalog.now())
  on conflict (profile_id, visitor_id)
  do update set last_visited_at = excluded.last_visited_at;
end;
$$;

create or replace function public.my_profile_visitor_count()
returns bigint
language sql
stable
security definer
set search_path = ''
as $$
  select pg_catalog.count(*)::bigint
  from public.profile_visits v
  where v.profile_id = auth.uid();
$$;

revoke all on function public.record_profile_visit(uuid) from public, anon;
revoke all on function public.my_profile_visitor_count() from public, anon;
grant execute on function public.record_profile_visit(uuid) to authenticated;
grant execute on function public.my_profile_visitor_count() to authenticated;
