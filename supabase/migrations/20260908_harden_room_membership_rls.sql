drop policy if exists saki_room_members_insert on public.room_members;
drop policy if exists saki_room_members_update on public.room_members;
drop policy if exists saki_room_seats_insert on public.room_seats;
drop policy if exists saki_room_seats_update on public.room_seats;
create policy saki_room_seats_insert_member on public.room_seats for insert to authenticated
with check (auth.uid()=user_id and exists(select 1 from public.room_members rm where rm.room_id=room_seats.room_id and rm.user_id=auth.uid()));
create policy saki_room_seats_update_member on public.room_seats for update to authenticated
using ((auth.uid()=user_id) or exists(select 1 from public.rooms r where r.id=room_seats.room_id and r.owner_id=auth.uid()))
with check ((auth.uid()=user_id) or exists(select 1 from public.rooms r where r.id=room_seats.room_id and r.owner_id=auth.uid()));
