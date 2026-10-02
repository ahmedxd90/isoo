-- SAKI baseline schema for faxt. Local review draft only.
--
-- This is additive: it creates the source tables missing from the migration set,
-- restores source columns, and adds indexes/constraints. It imports no old user
-- data; only the preserved static gift catalog receives alias/ID values. Supabase Auth
-- owns auth.users, so auth_users/auth_sessions are intentionally not created.
-- public.voice_rooms is unrelated to the source public.rooms table and is untouched.

create sequence if not exists public.saki_id_seq minvalue 964379846 start 964379846;

-- Baseline tables that are not created by the checked-in migrations and are
-- absent from the current target. Profiles deliberately references Supabase Auth.
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
  visibility text not null,
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
  created_at timestamptz,
  primary key (post_id, user_id)
);

create table if not exists public.follows (
  follower_id uuid not null references public.profiles(id) on delete cascade,
  following_id uuid not null references public.profiles(id) on delete cascade,
  created_at timestamptz,
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
  visibility text not null,
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

-- Source-column compatibility for tables already present in faxt. Added columns
-- start nullable so existing rows are not rewritten. Gift-catalog aliases are the
-- only intentional reference-data adaptation in this migration.
alter table public.posts
  add column if not exists author_id uuid,
  add column if not exists visibility text;

alter table public.conversations
  add column if not exists created_by uuid;

alter table public.messages
  add column if not exists body text,
  add column if not exists is_read boolean,
  add column if not exists message_type text,
  add column if not exists media_url text,
  add column if not exists media_name text;

-- Defaults apply only to future inserts; existing rows are not rewritten.
alter table public.messages
  alter column is_read set default false,
  alter column message_type set default 'text';

alter table public.notifications
  add column if not exists entity_id uuid,
  add column if not exists is_read boolean,
  add column if not exists badge_key text,
  add column if not exists badge_asset_path text,
  add column if not exists data text;

alter table public.notifications alter column is_read set default false;

alter table public.room_messages
  add column if not exists id uuid,
  add column if not exists sender_id uuid,
  add column if not exists body text,
  add column if not exists payload jsonb;

alter table public.room_messages alter column id set default gen_random_uuid();

alter table public.room_bans
  add column if not exists banned_by uuid;

alter table public.room_moderators
  add column if not exists created_by uuid;

alter table public.room_gift_catalog
  add column if not exists id uuid,
  add column if not exists name text,
  add column if not exists icon text,
  add column if not exists sort_order integer,
  add column if not exists media_url text,
  add column if not exists media_type text;

alter table public.room_gift_catalog alter column id set default gen_random_uuid();
alter table public.room_gift_catalog
  alter column gift_type set default ('custom_' || gen_random_uuid()::text);

-- Preserve the existing system gift catalog by adapting its aliases instead of
-- discarding it. The seed migration later uses ON CONFLICT DO NOTHING, so this
-- natural key prevents duplicate names such as the existing rose and heart.
with numbered as (
  select ctid, (row_number() over (order by gift_type) - 1)::integer as ordinal
  from public.room_gift_catalog
)
update public.room_gift_catalog as g
set id = coalesce(g.id, gen_random_uuid()),
    name = coalesce(g.name, g.display_name, g.gift_type),
    icon = coalesce(g.icon, g.emoji, '🎁'),
    sort_order = coalesce(g.sort_order, numbered.ordinal),
    media_url = coalesce(g.media_url, g.asset_url),
    media_type = coalesce(
      g.media_type,
      case
        when coalesce(g.asset_url, '') ~* '[.]svga([?#].*)?$' then 'svga'
        when coalesce(g.asset_url, '') ~* '[.](mp4|webm)([?#].*)?$' then 'video'
        when coalesce(g.asset_url, '') ~* '[.]gif([?#].*)?$' then 'gif'
        else 'image'
      end
    )
from numbered
where g.ctid = numbered.ctid;

update public.room_gift_catalog
set category = 'luck'
where category = 'bag';

alter table public.room_gift_catalog
  alter column id set not null,
  alter column name set not null,
  alter column icon set not null,
  alter column sort_order set default 0,
  alter column sort_order set not null;

alter table public.room_gifts
  add column if not exists recipient_id uuid,
  add column if not exists gift_id uuid,
  add column if not exists total_price bigint,
  add column if not exists recipient_diamonds bigint;

alter table public.user_reports
  add column if not exists reported_id uuid,
  add column if not exists category text,
  add column if not exists details text,
  add column if not exists evidence_url text;

-- room_follows, conversation_members and room_seat_invites already expose all
-- source columns; their target-only extras are retained unchanged. trace_agencies
-- is supplied by later checked-in migrations; its legacy payout table is added
-- separately after that parent exists.

-- Unique indexes make the backfilled gift IDs and natural gift names referenceable
-- while retaining the old gift_type primary key.
create unique index if not exists room_gift_catalog_id_compat_uidx
  on public.room_gift_catalog (id);
create unique index if not exists room_gift_catalog_category_name_compat_uidx
  on public.room_gift_catalog (category, name);
create unique index if not exists room_messages_id_compat_uidx
  on public.room_messages (id);

-- Expected query indexes. Existing indexes with these names are left untouched.
create index if not exists posts_created_at_idx on public.posts (created_at desc);
create index if not exists posts_author_id_idx on public.posts (author_id);
create index if not exists post_media_post_id_idx on public.post_media (post_id, sort_order);
create index if not exists post_comments_post_id_idx on public.post_comments (post_id);
create index if not exists post_comments_user_id_idx on public.post_comments (user_id);
create index if not exists follows_following_id_idx on public.follows (following_id);
create unique index if not exists rooms_room_id_key on public.rooms (room_id);
create index if not exists rooms_owner_id_idx on public.rooms (owner_id);
create index if not exists reels_created_at_idx on public.reels (created_at desc);
create index if not exists reels_author_id_idx on public.reels (author_id);
create index if not exists reel_comments_reel_id_idx on public.reel_comments (reel_id);
create index if not exists reel_comments_user_id_idx on public.reel_comments (user_id);
create index if not exists room_members_user_id_idx on public.room_members (user_id);
create index if not exists room_seats_user_id_idx on public.room_seats (user_id);
create index if not exists messages_conversation_created_at_idx on public.messages (conversation_id, created_at);
create index if not exists room_messages_room_created_at_idx on public.room_messages (room_id, created_at);
create index if not exists notifications_user_created_at_idx on public.notifications (user_id, created_at desc);

-- NOT VALID installs FK enforcement for new/changed rows without scanning legacy
-- rows during deployment. Existing equivalent FKs are detected to avoid duplicates;
-- validate these references after baseline aliases and source migrations are ready.
do $$
declare
  r record;
  source_attnum smallint;
begin
  for r in
    select * from (values
      ('public.posts', 'author_id', 'public.profiles', 'id', 'CASCADE'),
      ('public.conversations', 'created_by', 'public.profiles', 'id', 'SET NULL'),
      ('public.conversation_members', 'conversation_id', 'public.conversations', 'id', 'CASCADE'),
      ('public.conversation_members', 'user_id', 'public.profiles', 'id', 'CASCADE'),
      ('public.messages', 'conversation_id', 'public.conversations', 'id', 'CASCADE'),
      ('public.messages', 'sender_id', 'public.profiles', 'id', 'SET NULL'),
      ('public.notifications', 'user_id', 'public.profiles', 'id', 'CASCADE'),
      ('public.notifications', 'actor_id', 'public.profiles', 'id', 'SET NULL'),
      ('public.room_messages', 'room_id', 'public.rooms', 'id', 'CASCADE'),
      ('public.room_messages', 'sender_id', 'public.profiles', 'id', 'CASCADE'),
      ('public.room_bans', 'room_id', 'public.rooms', 'id', 'CASCADE'),
      ('public.room_bans', 'user_id', 'public.profiles', 'id', 'CASCADE'),
      ('public.room_bans', 'banned_by', 'public.profiles', 'id', 'CASCADE'),
      ('public.room_follows', 'room_id', 'public.rooms', 'id', 'CASCADE'),
      ('public.room_follows', 'user_id', 'public.profiles', 'id', 'CASCADE'),
      ('public.room_gifts', 'room_id', 'public.rooms', 'id', 'CASCADE'),
      ('public.room_gifts', 'sender_id', 'public.profiles', 'id', 'CASCADE'),
      ('public.room_gifts', 'recipient_id', 'public.profiles', 'id', 'CASCADE'),
      ('public.room_gifts', 'gift_id', 'public.room_gift_catalog', 'id', 'RESTRICT'),
      ('public.room_moderators', 'room_id', 'public.rooms', 'id', 'CASCADE'),
      ('public.room_moderators', 'user_id', 'public.profiles', 'id', 'CASCADE'),
      ('public.room_moderators', 'created_by', 'public.profiles', 'id', 'CASCADE'),
      ('public.room_seat_invites', 'room_id', 'public.rooms', 'id', 'CASCADE'),
      ('public.room_seat_invites', 'inviter_id', 'public.profiles', 'id', 'CASCADE'),
      ('public.room_seat_invites', 'invitee_id', 'public.profiles', 'id', 'CASCADE'),
      ('public.user_reports', 'reporter_id', 'public.profiles', 'id', 'CASCADE'),
      ('public.user_reports', 'reported_id', 'public.profiles', 'id', 'CASCADE'),
      ('public.user_reports', 'room_id', 'public.rooms', 'id', 'SET NULL')
    ) as refs(table_name, column_name, referenced_table, referenced_column, delete_action)
  loop
    select a.attnum into source_attnum
    from pg_attribute a
    where a.attrelid = to_regclass(r.table_name)
      and a.attname = r.column_name
      and not a.attisdropped;

    if source_attnum is not null and not exists (
      select 1
      from pg_constraint c
      where c.contype = 'f'
        and c.conrelid = to_regclass(r.table_name)
        and c.confrelid = to_regclass(r.referenced_table)
        and c.conkey = array[source_attnum]::smallint[]
    ) then
      execute format(
        'alter table %s add constraint %I foreign key (%I) references %s (%I) on delete %s not valid',
        to_regclass(r.table_name),
        'saki_base_' || replace(split_part(r.table_name, '.', 2), ' ', '') || '_' || r.column_name || '_fkey',
        r.column_name,
        to_regclass(r.referenced_table),
        r.referenced_column,
        r.delete_action
      );
    end if;
  end loop;
end
$$;

-- Enable RLS only on tables that have policy definitions in the checked-in
-- policy migrations. No policies are invented for the remaining baseline tables.
alter table public.posts enable row level security;
alter table public.post_media enable row level security;
alter table public.rooms enable row level security;
alter table public.room_members enable row level security;
alter table public.room_seats enable row level security;
alter table public.conversations enable row level security;
alter table public.conversation_members enable row level security;
alter table public.messages enable row level security;
alter table public.notifications enable row level security;
alter table public.room_messages enable row level security;
alter table public.room_bans enable row level security;
alter table public.room_follows enable row level security;
alter table public.room_gift_catalog enable row level security;
alter table public.room_gifts enable row level security;
alter table public.room_moderators enable row level security;
alter table public.room_seat_invites enable row level security;
alter table public.user_reports enable row level security;
