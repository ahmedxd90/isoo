alter table public.room_seats add column if not exists is_speaking boolean not null default false;
