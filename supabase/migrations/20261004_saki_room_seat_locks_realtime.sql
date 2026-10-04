do $$
begin
  if not exists (
    select 1
    from pg_publication_tables
    where pubname = 'supabase_realtime'
      and schemaname = 'public'
      and tablename = 'room_seat_locks'
  ) then
    alter publication supabase_realtime add table public.room_seat_locks;
  end if;
end
$$;
