create extension if not exists pgcrypto;

create sequence if not exists public.saki_id_seq minvalue 964379846 start 964379846;
alter table public.profiles alter column saki_id set default nextval('public.saki_id_seq'::regclass);
select setval('public.saki_id_seq', greatest(coalesce((select max(saki_id) from public.profiles), 964379845), 964379845), true);

alter table public.profiles add column if not exists display_name text;
alter table public.profiles add column if not exists is_private boolean not null default false;
alter table public.profiles add column if not exists updated_at timestamptz not null default now();

alter table public.posts add column if not exists updated_at timestamptz not null default now();
alter table public.reels add column if not exists updated_at timestamptz not null default now();
alter table public.reels add column if not exists thumbnail_url text;
alter table public.reels add column if not exists video_path text;
alter table public.rooms add column if not exists room_id text;
alter table public.rooms add column if not exists image_url text;
alter table public.rooms add column if not exists is_active boolean not null default true;
alter table public.conversations add column if not exists created_by uuid references public.profiles(id) on delete set null;
alter table public.conversations add column if not exists updated_at timestamptz not null default now();
alter table public.messages add column if not exists is_read boolean not null default false;

update public.rooms set room_id = 'SAKI-' || upper(substr(replace(gen_random_uuid()::text, '-', ''), 1, 8)) where room_id is null;
alter table public.rooms alter column room_id set default ('SAKI-' || upper(substr(replace(gen_random_uuid()::text, '-', ''), 1, 8)));
create unique index if not exists rooms_room_id_key on public.rooms(room_id);

create table if not exists public.post_shares (
  post_id uuid not null references public.posts(id) on delete cascade,
  user_id uuid not null references public.profiles(id) on delete cascade,
  created_at timestamptz not null default now(),
  primary key (post_id, user_id)
);

create table if not exists public.reel_media (
  id uuid primary key default gen_random_uuid(),
  reel_id uuid not null references public.reels(id) on delete cascade,
  storage_path text not null,
  sort_order integer not null default 0
);

create table if not exists public.reel_shares (
  reel_id uuid not null references public.reels(id) on delete cascade,
  user_id uuid not null references public.profiles(id) on delete cascade,
  created_at timestamptz not null default now(),
  primary key (reel_id, user_id)
);

create table if not exists public.room_messages (
  id uuid primary key default gen_random_uuid(),
  room_id uuid not null references public.rooms(id) on delete cascade,
  sender_id uuid not null references public.profiles(id) on delete cascade,
  body text not null,
  created_at timestamptz not null default now()
);

create table if not exists public.room_banners (
  id uuid primary key default gen_random_uuid(),
  image_url text not null,
  title text,
  sort_order integer not null default 0,
  is_active boolean not null default true,
  created_at timestamptz not null default now()
);

create table if not exists public.countries (
  code text primary key,
  name text not null,
  name_ar text not null,
  flag text not null
);

create index if not exists posts_created_at_idx on public.posts(created_at desc);
create index if not exists posts_author_id_idx on public.posts(author_id);
create index if not exists post_media_post_id_idx on public.post_media(post_id, sort_order);
create index if not exists reels_created_at_idx on public.reels(created_at desc);
create index if not exists messages_conversation_created_at_idx on public.messages(conversation_id, created_at);
create index if not exists room_messages_room_created_at_idx on public.room_messages(room_id, created_at);
create index if not exists notifications_user_created_at_idx on public.notifications(user_id, created_at desc);
create index if not exists room_banners_active_sort_idx on public.room_banners(is_active, sort_order);

create or replace function public.handle_new_user()
returns trigger
language plpgsql
security definer set search_path = public
as $$
declare
  generated_username text;
begin
  generated_username := coalesce(nullif(new.raw_user_meta_data->>'username', ''), 'user_' || substr(replace(new.id::text, '-', ''), 1, 10));
  insert into public.profiles (id, username, display_name, avatar_url, country, gender)
  values (
    new.id,
    generated_username,
    nullif(new.raw_user_meta_data->>'display_name', ''),
    nullif(new.raw_user_meta_data->>'avatar_url', ''),
    nullif(new.raw_user_meta_data->>'country', ''),
    nullif(new.raw_user_meta_data->>'gender', '')
  )
  on conflict (id) do nothing;
  return new;
end;
$$;

drop trigger if exists on_auth_user_created on auth.users;
create trigger on_auth_user_created
after insert on auth.users
for each row execute procedure public.handle_new_user();

alter table public.post_shares enable row level security;
alter table public.reel_media enable row level security;
alter table public.reel_shares enable row level security;
alter table public.room_messages enable row level security;
alter table public.room_banners enable row level security;
alter table public.countries enable row level security;

-- Tighten the existing post read/write rules while keeping public posts discoverable.
drop policy if exists "posts_read" on public.posts;
drop policy if exists "public posts readable" on public.posts;
drop policy if exists "own posts update" on public.posts;
drop policy if exists "own posts delete" on public.posts;
drop policy if exists "posts_owner" on public.posts;
drop policy if exists "own posts insert" on public.posts;
drop policy if exists "posts_insert" on public.posts;
create policy "saki_posts_select" on public.posts for select using (
  visibility = 'public'
  or author_id = auth.uid()
  or exists (select 1 from public.follows f where f.follower_id = auth.uid() and f.following_id = posts.author_id)
);
create policy "saki_posts_insert" on public.posts for insert with check (auth.uid() = author_id);
create policy "saki_posts_update" on public.posts for update using (auth.uid() = author_id) with check (auth.uid() = author_id);
create policy "saki_posts_delete" on public.posts for delete using (auth.uid() = author_id);

drop policy if exists "media_read" on public.post_media;
create policy "saki_post_media_select" on public.post_media for select using (
  exists (
    select 1 from public.posts p
    where p.id = post_media.post_id
      and (p.visibility = 'public' or p.author_id = auth.uid()
        or exists (select 1 from public.follows f where f.follower_id = auth.uid() and f.following_id = p.author_id))
  )
);
create policy "saki_post_media_delete" on public.post_media for delete using (
  exists (select 1 from public.posts p where p.id = post_media.post_id and p.author_id = auth.uid())
);

create policy "saki_post_shares_select" on public.post_shares for select using (true);
create policy "saki_post_shares_insert" on public.post_shares for insert with check (auth.uid() = user_id);
create policy "saki_post_shares_delete" on public.post_shares for delete using (auth.uid() = user_id);

create policy "saki_reel_media_select" on public.reel_media for select using (
  exists (select 1 from public.reels r where r.id = reel_media.reel_id and (r.visibility = 'public' or r.author_id = auth.uid()))
);
create policy "saki_reel_media_insert" on public.reel_media for insert with check (
  exists (select 1 from public.reels r where r.id = reel_media.reel_id and r.author_id = auth.uid())
);
create policy "saki_reel_media_delete" on public.reel_media for delete using (
  exists (select 1 from public.reels r where r.id = reel_media.reel_id and r.author_id = auth.uid())
);

create policy "saki_reel_shares_select" on public.reel_shares for select using (true);
create policy "saki_reel_shares_insert" on public.reel_shares for insert with check (auth.uid() = user_id);
create policy "saki_reel_shares_delete" on public.reel_shares for delete using (auth.uid() = user_id);

create policy "saki_conversations_select" on public.conversations for select using (
  exists (select 1 from public.conversation_members cm where cm.conversation_id = conversations.id and cm.user_id = auth.uid())
);
create policy "saki_conversations_insert" on public.conversations for insert with check (auth.uid() = created_by);
create policy "saki_conversation_members_select" on public.conversation_members for select using (
  exists (select 1 from public.conversation_members own where own.conversation_id = conversation_members.conversation_id and own.user_id = auth.uid())
);
create policy "saki_conversation_members_insert" on public.conversation_members for insert with check (
  auth.uid() = user_id or exists (select 1 from public.conversations c where c.id = conversation_id and c.created_by = auth.uid())
);
create policy "saki_messages_update" on public.messages for update using (
  exists (select 1 from public.conversation_members cm where cm.conversation_id = messages.conversation_id and cm.user_id = auth.uid())
) with check (sender_id = messages.sender_id);

create policy "saki_room_members_select" on public.room_members for select using (
  user_id = auth.uid() or exists (select 1 from public.room_members rm where rm.room_id = room_members.room_id and rm.user_id = auth.uid())
);
create policy "saki_room_members_insert" on public.room_members for insert with check (auth.uid() = user_id);
create policy "saki_room_members_delete" on public.room_members for delete using (auth.uid() = user_id or exists (select 1 from public.rooms r where r.id = room_members.room_id and r.owner_id = auth.uid()));
create policy "saki_room_messages_select" on public.room_messages for select using (
  exists (select 1 from public.room_members rm where rm.room_id = room_messages.room_id and rm.user_id = auth.uid())
  or exists (select 1 from public.rooms r where r.id = room_messages.room_id and r.owner_id = auth.uid())
);
create policy "saki_room_messages_insert" on public.room_messages for insert with check (
  auth.uid() = sender_id and (
    exists (select 1 from public.room_members rm where rm.room_id = room_messages.room_id and rm.user_id = auth.uid())
    or exists (select 1 from public.rooms r where r.id = room_messages.room_id and r.owner_id = auth.uid())
  )
);
create policy "saki_room_messages_delete" on public.room_messages for delete using (auth.uid() = sender_id);
create policy "saki_room_banners_select" on public.room_banners for select using (is_active = true);
create policy "saki_countries_select" on public.countries for select using (true);

create policy "saki_notifications_select" on public.notifications for select using (auth.uid() = user_id);
create policy "saki_notifications_update" on public.notifications for update using (auth.uid() = user_id) with check (auth.uid() = user_id);
create policy "saki_notifications_insert" on public.notifications for insert with check (auth.uid() = actor_id);

insert into storage.buckets (id, name, public)
values
  ('avatars', 'avatars', true),
  ('posts', 'posts', true),
  ('reels', 'reels', true),
  ('rooms', 'rooms', true),
  ('banners', 'banners', true)
on conflict (id) do update set public = excluded.public;

create policy "saki_storage_public_read" on storage.objects for select using (bucket_id in ('avatars','posts','reels','rooms','banners'));
create policy "saki_storage_owner_insert" on storage.objects for insert with check (
  bucket_id in ('avatars','posts','reels','rooms') and (storage.foldername(name))[1] = auth.uid()::text
);
create policy "saki_storage_owner_update" on storage.objects for update using (
  bucket_id in ('avatars','posts','reels','rooms') and owner_id = auth.uid()::text
) with check (bucket_id in ('avatars','posts','reels','rooms') and owner_id = auth.uid()::text);
create policy "saki_storage_owner_delete" on storage.objects for delete using (
  bucket_id in ('avatars','posts','reels','rooms') and owner_id = auth.uid()::text
);

DO $$
DECLARE
  table_name text;
BEGIN
  FOREACH table_name IN ARRAY ARRAY['messages','post_likes','post_comments','follows','notifications','room_members','room_messages'] LOOP
    IF NOT EXISTS (
      SELECT 1 FROM pg_publication_tables
      WHERE pubname = 'supabase_realtime' AND schemaname = 'public' AND tablename = table_name
    ) THEN
      EXECUTE format('alter publication supabase_realtime add table public.%I', table_name);
    END IF;
  END LOOP;
END $$;

insert into public.countries (code, name, name_ar, flag) values
('JO','Jordan','الأردن','🇯🇴'),('SA','Saudi Arabia','السعودية','🇸🇦'),('AE','United Arab Emirates','الإمارات','🇦🇪'),('EG','Egypt','مصر','🇪🇬'),('IQ','Iraq','العراق','🇮🇶'),('SY','Syria','سوريا','🇸🇾'),('LB','Lebanon','لبنان','🇱🇧'),('PS','Palestine','فلسطين','🇵🇸'),('KW','Kuwait','الكويت','🇰🇼'),('QA','Qatar','قطر','🇶🇦'),('BH','Bahrain','البحرين','🇧🇭'),('OM','Oman','عُمان','🇴🇲'),('YE','Yemen','اليمن','🇾🇪'),('MA','Morocco','المغرب','🇲🇦'),('DZ','Algeria','الجزائر','🇩🇿'),('TN','Tunisia','تونس','🇹🇳'),('LY','Libya','ليبيا','🇱🇾'),('SD','Sudan','السودان','🇸🇩'),('TR','Turkey','تركيا','🇹🇷'),('IR','Iran','إيران','🇮🇷'),('US','United States','الولايات المتحدة','🇺🇸'),('GB','United Kingdom','المملكة المتحدة','🇬🇧'),('CA','Canada','كندا','🇨🇦'),('AU','Australia','أستراليا','🇦🇺'),('DE','Germany','ألمانيا','🇩🇪'),('FR','France','فرنسا','🇫🇷'),('IT','Italy','إيطاليا','🇮🇹'),('ES','Spain','إسبانيا','🇪🇸'),('NL','Netherlands','هولندا','🇳🇱'),('SE','Sweden','السويد','🇸🇪'),('NO','Norway','النرويج','🇳🇴'),('IN','India','الهند','🇮🇳'),('PK','Pakistan','باكستان','🇵🇰'),('BD','Bangladesh','بنغلاديش','🇧🇩'),('ID','Indonesia','إندونيسيا','🇮🇩'),('MY','Malaysia','ماليزيا','🇲🇾'),('SG','Singapore','سنغافورة','🇸🇬'),('JP','Japan','اليابان','🇯🇵'),('KR','South Korea','كوريا الجنوبية','🇰🇷'),('CN','China','الصين','🇨🇳'),('BR','Brazil','البرازيل','🇧🇷'),('MX','Mexico','المكسيك','🇲🇽'),('ZA','South Africa','جنوب أفريقيا','🇿🇦'),('NG','Nigeria','نيجيريا','🇳🇬'),('ET','Ethiopia','إثيوبيا','🇪🇹'),('KE','Kenya','كينيا','🇰🇪'),('RU','Russia','روسيا','🇷🇺'),('UA','Ukraine','أوكرانيا','🇺🇦'),('GR','Greece','اليونان','🇬🇷'),('PT','Portugal','البرتغال','🇵🇹'),('CH','Switzerland','سويسرا','🇨🇭')
on conflict (code) do nothing;
