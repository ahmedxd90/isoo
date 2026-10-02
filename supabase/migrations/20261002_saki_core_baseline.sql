-- Core PostgreSQL baseline for the isoo application on faxt.
-- The isoo migration set assumes these foundational tables exist.
create extension if not exists pgcrypto;
create sequence if not exists public.saki_id_seq minvalue 964379846 start 964379846;

create table if not exists public.profiles (
  id uuid primary key references auth.users(id) on delete cascade,
  username text not null unique,
  saki_id bigint unique default nextval('public.saki_id_seq'::regclass),
  avatar_url text,
  bio text,
  country text,
  gender text,
  created_at timestamptz not null default now(),
  country_code text not null default '',
  display_name text,
  is_private boolean not null default false,
  updated_at timestamptz not null default now(),
  vip_level integer not null default 0,
  vip_expires_at timestamptz,
  is_super_admin boolean not null default false,
  super_admin_label text,
  wealth_xp bigint not null default 0,
  wealth_level integer not null default 0,
  charm_xp bigint not null default 0,
  charm_level integer not null default 0,
  vip_frame_enabled boolean not null default true,
  country_updated_at timestamptz,
  admin_role text not null default 'user'
);

create table if not exists public.rooms (
  id uuid primary key default gen_random_uuid(),
  owner_id uuid not null references public.profiles(id) on delete cascade,
  name text not null,
  description text,
  country text,
  room_type text,
  created_at timestamptz not null default now(),
  room_id text,
  image_url text,
  is_active boolean not null default true,
  seat_count integer not null default 0,
  background_url text,
  is_official boolean not null default false,
  announcement text,
  category text not null default 'عام',
  theme_key text not null default 'default',
  membership_fee integer not null default 0,
  reward_rate numeric(20,6) not null default 0,
  mic_permission text not null default 'everyone',
  is_pinned boolean not null default false,
  pin_priority integer not null default 0
);

create table if not exists public.posts (
  id uuid primary key default gen_random_uuid(),
  author_id uuid not null references public.profiles(id) on delete cascade,
  content text,
  visibility text not null default 'public',
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);
create table if not exists public.post_media (
  id uuid primary key default gen_random_uuid(),
  post_id uuid not null references public.posts(id) on delete cascade,
  storage_path text not null,
  sort_order integer not null default 0
);
create table if not exists public.post_likes (
  post_id uuid not null references public.posts(id) on delete cascade,
  user_id uuid not null references public.profiles(id) on delete cascade,
  created_at timestamptz not null default now(),
  primary key (post_id, user_id)
);
create table if not exists public.follows (
  follower_id uuid not null references public.profiles(id) on delete cascade,
  following_id uuid not null references public.profiles(id) on delete cascade,
  created_at timestamptz not null default now(),
  primary key (follower_id, following_id),
  constraint follows_no_self_follow check (follower_id <> following_id)
);
create table if not exists public.post_comments (
  id uuid primary key default gen_random_uuid(),
  post_id uuid not null references public.posts(id) on delete cascade,
  user_id uuid not null references public.profiles(id) on delete cascade,
  content text not null,
  created_at timestamptz not null default now()
);
create table if not exists public.reels (
  id uuid primary key default gen_random_uuid(),
  author_id uuid not null references public.profiles(id) on delete cascade,
  video_url text not null,
  description text,
  visibility text not null default 'public',
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  thumbnail_url text,
  video_path text
);
create table if not exists public.room_members (
  room_id uuid not null references public.rooms(id) on delete cascade,
  user_id uuid not null references public.profiles(id) on delete cascade,
  joined_at timestamptz not null default now(),
  last_seen timestamptz not null default now(),
  primary key (room_id, user_id)
);
create table if not exists public.reel_comments (
  id uuid primary key default gen_random_uuid(),
  reel_id uuid not null references public.reels(id) on delete cascade,
  user_id uuid not null references public.profiles(id) on delete cascade,
  content text not null,
  created_at timestamptz not null default now()
);
create table if not exists public.reel_likes (
  reel_id uuid not null references public.reels(id) on delete cascade,
  user_id uuid not null references public.profiles(id) on delete cascade,
  created_at timestamptz not null default now(),
  primary key (reel_id, user_id)
);
create table if not exists public.room_seats (
  room_id uuid not null references public.rooms(id) on delete cascade,
  seat_no integer not null default 0,
  user_id uuid not null references public.profiles(id) on delete cascade,
  joined_at timestamptz not null default now(),
  is_speaking boolean not null default false,
  primary key (room_id, seat_no)
);

-- These four legacy baseline entities are referenced by the isoo foundation
-- migration but have no CREATE TABLE statement in the checked-in SQL set.
create table if not exists public.conversations (
  id uuid primary key default gen_random_uuid(),
  created_at timestamptz not null default now(),
  created_by uuid references public.profiles(id) on delete set null,
  updated_at timestamptz not null default now()
);
create table if not exists public.conversation_members (
  conversation_id uuid not null references public.conversations(id) on delete cascade,
  user_id uuid not null references public.profiles(id) on delete cascade,
  joined_at timestamptz not null default now(),
  primary key (conversation_id, user_id)
);
create table if not exists public.messages (
  id uuid primary key default gen_random_uuid(),
  conversation_id uuid references public.conversations(id) on delete cascade,
  sender_id uuid references public.profiles(id) on delete set null,
  body text not null,
  created_at timestamptz not null default now(),
  is_read boolean not null default false,
  message_type text not null default 'text',
  media_url text,
  media_name text
);
create table if not exists public.notifications (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references public.profiles(id) on delete cascade,
  actor_id uuid references public.profiles(id) on delete set null,
  type text not null,
  entity_id uuid,
  is_read boolean not null default false,
  created_at timestamptz not null default now(),
  badge_key text,
  badge_asset_path text,
  data text not null default '{}'
);

create index if not exists posts_created_at_idx on public.posts(created_at desc);
create index if not exists posts_author_id_idx on public.posts(author_id);
create index if not exists post_media_post_id_idx on public.post_media(post_id, sort_order);
create index if not exists post_comments_post_id_idx on public.post_comments(post_id);
create index if not exists post_comments_user_id_idx on public.post_comments(user_id);
create index if not exists follows_following_id_idx on public.follows(following_id);
create index if not exists reels_created_at_idx on public.reels(created_at desc);
create index if not exists reels_author_id_idx on public.reels(author_id);
create index if not exists messages_conversation_created_at_idx on public.messages(conversation_id, created_at);
create index if not exists notifications_user_created_at_idx on public.notifications(user_id, created_at desc);

alter table public.profiles enable row level security;
alter table public.rooms enable row level security;
alter table public.posts enable row level security;
alter table public.post_media enable row level security;
alter table public.post_likes enable row level security;
alter table public.follows enable row level security;
alter table public.post_comments enable row level security;
alter table public.reels enable row level security;
alter table public.room_members enable row level security;
alter table public.reel_comments enable row level security;
alter table public.reel_likes enable row level security;
alter table public.room_seats enable row level security;
alter table public.conversations enable row level security;
alter table public.conversation_members enable row level security;
alter table public.messages enable row level security;
alter table public.notifications enable row level security;
