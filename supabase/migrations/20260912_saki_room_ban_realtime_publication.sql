do $$
begin
  if not exists (
    select 1 from pg_publication_tables
    where pubname = 'supabase_realtime'
      and schemaname = 'public'
      and tablename = 'room_bans'
  ) then
    alter publication supabase_realtime add table public.room_bans;
  end if;
end $$;
