drop policy if exists room_bans_target_read on public.room_bans;
create policy room_bans_target_read on public.room_bans
for select to authenticated
using (user_id = auth.uid());
