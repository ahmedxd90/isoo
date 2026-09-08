do $$
begin
  alter publication supabase_realtime add table public.room_luck_bags;
exception when duplicate_object then null;
end $$;
