-- Global gift banners are fed by one public realtime table for every room.
do $$
begin
  if not exists (
    select 1 from pg_publication_tables
    where pubname = 'supabase_realtime' and schemaname = 'public' and tablename = 'gift_announcements'
  ) then
    alter publication supabase_realtime add table public.gift_announcements;
  end if;
end $$;

alter table public.gift_announcements enable row level security;
drop policy if exists gift_announcements_realtime_read on public.gift_announcements;
create policy gift_announcements_realtime_read on public.gift_announcements
  for select to authenticated using (true);

comment on table public.gift_announcements is 'Global high-value gift events; Flutter displays events >= 50,000 gold coins once for all authenticated users.';
