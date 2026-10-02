-- Final parity pass for SAKI features omitted by the historical migration sequence.
-- Keep private messages member-scoped, restore report/reaction workflows, and
-- preserve profile, admin, wealth progression, and room-owner behavior.

-- A non-exposed helper prevents recursive RLS when reading conversation members.
create schema if not exists private;
revoke all on schema private from public, anon;
grant usage on schema private to authenticated;

create or replace function private.is_private_conversation_member(p_conversation_id uuid)
returns boolean
language sql
stable
security definer
set search_path = pg_catalog, public, pg_temp
as $$
  select exists (
    select 1
    from public.conversation_members cm
    where cm.conversation_id = p_conversation_id
      and cm.user_id = (select auth.uid())
  );
$$;
revoke all on function private.is_private_conversation_member(uuid) from public, anon, authenticated;
grant execute on function private.is_private_conversation_member(uuid) to authenticated;

alter table public.conversations enable row level security;
alter table public.conversation_members enable row level security;
alter table public.messages enable row level security;

do $$
declare r record;
begin
  for r in
    select schemaname, tablename, policyname
    from pg_policies
    where schemaname = 'public'
      and tablename in ('conversations', 'conversation_members', 'messages')
  loop
    execute format('drop policy if exists %I on public.%I', r.policyname, r.tablename);
  end loop;
end;
$$;

revoke all privileges on table public.conversations, public.conversation_members, public.messages
  from public, anon, authenticated;
grant select on table public.conversations, public.conversation_members, public.messages to authenticated;
grant insert (conversation_id, sender_id, body, message_type, media_url, media_name)
  on table public.messages to authenticated;
grant update (is_read) on table public.messages to authenticated;
grant delete on table public.messages to authenticated;
grant all privileges on table public.conversations, public.conversation_members, public.messages to service_role;

create policy saki_conversations_select
  on public.conversations for select to authenticated
  using (private.is_private_conversation_member(id));
create policy saki_conversation_members_select
  on public.conversation_members for select to authenticated
  using (private.is_private_conversation_member(conversation_id));
create policy saki_messages_select
  on public.messages for select to authenticated
  using (private.is_private_conversation_member(conversation_id));
create policy saki_messages_insert
  on public.messages for insert to authenticated
  with check (
    sender_id = (select auth.uid())
    and private.is_private_conversation_member(conversation_id)
  );
-- Receivers may mark incoming messages as read; column privileges prevent
-- changing sender/body/media content through this UPDATE path.
create policy saki_messages_update_read
  on public.messages for update to authenticated
  using (private.is_private_conversation_member(conversation_id))
  with check (private.is_private_conversation_member(conversation_id));
create policy saki_messages_delete_own
  on public.messages for delete to authenticated
  using (
    sender_id = (select auth.uid())
    and private.is_private_conversation_member(conversation_id)
  );

do $$
begin
  if not exists (
    select 1 from pg_publication_tables
    where pubname = 'supabase_realtime' and schemaname = 'public' and tablename = 'messages'
  ) then
    alter publication supabase_realtime add table public.messages;
  end if;
end;
$$;

alter function public.create_private_conversation(uuid)
  set search_path = pg_catalog, public, pg_temp;
revoke all on function public.create_private_conversation(uuid) from public, anon;
grant execute on function public.create_private_conversation(uuid) to authenticated;
do $$
begin
  if to_regprocedure('public.is_private_conversation_member(uuid)') is not null then
    execute 'revoke all on function public.is_private_conversation_member(uuid) from public, anon, authenticated';
  end if;
end;
$$;

-- Message reactions used by the Flutter private-chat UI.
create table if not exists public.message_reactions (
  id uuid primary key default gen_random_uuid(),
  message_id uuid not null references public.messages(id) on delete cascade,
  conversation_id uuid not null references public.conversations(id) on delete cascade,
  user_id uuid not null references public.profiles(id) on delete cascade,
  emoji text not null check (emoji in ('😂', '❤️', '😭', '😮')),
  created_at timestamptz not null default now(),
  unique (message_id, user_id)
);
create index if not exists message_reactions_conversation_idx
  on public.message_reactions(conversation_id, created_at);
alter table public.message_reactions enable row level security;
revoke all privileges on table public.message_reactions from public, anon, authenticated;
grant select, insert, update, delete on table public.message_reactions to authenticated;
grant all privileges on table public.message_reactions to service_role;
drop policy if exists message_reactions_select on public.message_reactions;
drop policy if exists message_reactions_insert on public.message_reactions;
drop policy if exists message_reactions_update on public.message_reactions;
drop policy if exists message_reactions_delete on public.message_reactions;
create policy message_reactions_select on public.message_reactions for select to authenticated
  using (private.is_private_conversation_member(conversation_id));
create policy message_reactions_insert on public.message_reactions for insert to authenticated
  with check (
    user_id = (select auth.uid())
    and private.is_private_conversation_member(conversation_id)
  );
create policy message_reactions_update on public.message_reactions for update to authenticated
  using (user_id = (select auth.uid()) and private.is_private_conversation_member(conversation_id))
  with check (user_id = (select auth.uid()) and private.is_private_conversation_member(conversation_id));
create policy message_reactions_delete on public.message_reactions for delete to authenticated
  using (user_id = (select auth.uid()));
alter table public.message_reactions replica identity full;
do $$
begin
  if not exists (
    select 1 from pg_publication_tables
    where pubname = 'supabase_realtime' and schemaname = 'public' and tablename = 'message_reactions'
  ) then
    alter publication supabase_realtime add table public.message_reactions;
  end if;
end;
$$;

-- Room-scoped user reports and evidence uploads used by the moderation UI.
alter table public.user_reports
  add column if not exists room_id uuid references public.rooms(id) on delete set null,
  add column if not exists evidence_url text,
  add column if not exists status text not null default 'new';
alter table public.user_reports drop constraint if exists user_reports_category_check;
alter table public.user_reports add constraint user_reports_category_check
  check (category in ('sexual', 'advertising', 'abuse', 'other', 'promotion', 'harassment'));
alter table public.user_reports drop constraint if exists user_reports_status_check;
alter table public.user_reports add constraint user_reports_status_check
  check (status in ('new', 'reviewing', 'resolved', 'rejected'));
create index if not exists user_reports_room_idx on public.user_reports(room_id);
create index if not exists user_reports_status_idx on public.user_reports(status);
alter table public.user_reports enable row level security;
revoke all privileges on table public.user_reports from public, anon, authenticated;
grant select, insert on table public.user_reports to authenticated;
grant update (status) on table public.user_reports to authenticated;
grant all privileges on table public.user_reports to service_role;
drop policy if exists user_reports_insert on public.user_reports;
drop policy if exists user_reports_admin_select on public.user_reports;
drop policy if exists user_reports_admin_update on public.user_reports;
create policy user_reports_insert on public.user_reports for insert to authenticated
  with check (reporter_id = (select auth.uid()));
create policy user_reports_admin_select on public.user_reports for select to authenticated
  using (
    reporter_id = (select auth.uid())
    or public.is_saki_super_admin()
    or public.saki_has_admin_permission('manage_reports')
    or public.saki_has_admin_permission('support_users')
  );
create policy user_reports_admin_update on public.user_reports for update to authenticated
  using (public.is_saki_super_admin() or public.saki_has_admin_permission('manage_reports'))
  with check (public.is_saki_super_admin() or public.saki_has_admin_permission('manage_reports'));
insert into storage.buckets (id, name, public)
values ('report_evidence', 'report_evidence', true)
on conflict (id) do nothing;
drop policy if exists report_evidence_public_read on storage.objects;
drop policy if exists report_evidence_owner_insert on storage.objects;
create policy report_evidence_public_read on storage.objects for select
  using (bucket_id = 'report_evidence');
create policy report_evidence_owner_insert on storage.objects for insert to authenticated
  with check (bucket_id = 'report_evidence' and (storage.foldername(name))[1] = (select auth.uid())::text);

-- Server-enforced profile rules: country cooldown and VIP-only animated avatars.
alter table public.profiles add column if not exists country_updated_at timestamptz;
update public.profiles
set country_updated_at = updated_at
where country is not null and country_updated_at is null;
create or replace function public.enforce_profile_edit_rules()
returns trigger
language plpgsql
security definer
set search_path = pg_catalog, public, pg_temp
as $$
begin
  if new.country is distinct from old.country then
    if old.country_updated_at is not null
       and old.country_updated_at > now() - interval '30 days' then
      raise exception 'country_change_cooldown';
    end if;
    new.country_updated_at = now();
  end if;
  if new.avatar_url is distinct from old.avatar_url
     and (
       lower(coalesce(new.avatar_url, '')) like '%.gif'
       or lower(coalesce(new.avatar_url, '')) like '%.gif?%'
     ) then
    if coalesce(new.vip_level, 0) < 7
       or (new.vip_expires_at is not null and new.vip_expires_at <= now()) then
      raise exception 'vip7_required_for_gif';
    end if;
  end if;
  return new;
end;
$$;
revoke all on function public.enforce_profile_edit_rules() from public, anon, authenticated;
drop trigger if exists profile_edit_rules on public.profiles;
create trigger profile_edit_rules before update on public.profiles
  for each row execute function public.enforce_profile_edit_rules();

-- Permit the database-backed super-admin role to review content records.
do $$
declare t text;
begin
  foreach t in array array[
    'posts','post_comments','reels','reel_comments','messages','notifications','follows',
    'room_messages','room_bans','room_mutes','room_moderators','vip_transactions',
    'gift_announcements','room_banners'
  ] loop
    if to_regclass('public.' || t) is not null then
      execute format('alter table public.%I enable row level security', t);
      execute format('drop policy if exists saki_admin_read_%I on public.%I', t, t);
      execute format(
        'create policy saki_admin_read_%I on public.%I for select to authenticated using (public.is_saki_super_admin())',
        t, t
      );
    end if;
  end loop;
end;
$$;

-- Progressive wealth level costs, historical XP reconciliation, and an
-- idempotent trigger that covers every gift category without double counting.
create or replace function public.wealth_xp_required_for_level(p_level integer)
returns numeric
language plpgsql immutable
set search_path = pg_catalog, public, pg_temp
as $$
declare band integer; cost numeric;
begin
  if p_level <= 0 then return 0; end if;
  if p_level <= 10 then return 30000; end if;
  if p_level <= 20 then return 50000; end if;
  if p_level <= 30 then return 100000; end if;
  if p_level <= 40 then return 250000; end if;
  if p_level <= 50 then return 500000; end if;
  if p_level <= 60 then return 1000000; end if;
  if p_level <= 70 then return 2000000; end if;
  band := 70;
  cost := 2000000;
  while p_level > band loop
    band := band + 10;
    cost := cost * 2;
  end loop;
  return cost;
end;
$$;
create or replace function public.level_from_xp(p_xp numeric, p_kind text)
returns integer
language plpgsql immutable
set search_path = pg_catalog, public, pg_temp
as $$
declare level_no integer := 0; total numeric := 0; cost numeric;
begin
  if p_kind <> 'wealth' then
    for i in 1..500 loop
      cost := 20000 * power(2, i - 1);
      exit when p_xp < total + cost;
      total := total + cost;
      level_no := i;
    end loop;
    return level_no;
  end if;
  for i in 1..500 loop
    cost := public.wealth_xp_required_for_level(i);
    exit when p_xp < total + cost;
    total := total + cost;
    level_no := i;
  end loop;
  return level_no;
end;
$$;
create or replace function public.sync_user_levels(p_user_id uuid)
returns void
language plpgsql security definer
set search_path = pg_catalog, public, pg_temp
as $$
declare wxp bigint; cxp bigint; wl integer; cl integer;
begin
  select wealth_xp, charm_xp into wxp, cxp
  from public.saki_account_modules where user_id = p_user_id;
  wxp := coalesce(wxp, 0);
  cxp := coalesce(cxp, 0);
  wl := public.level_from_xp(wxp, 'wealth');
  cl := public.level_from_xp(cxp, 'charm');
  update public.saki_account_modules
  set wealth_level = wl, charm_level = cl, updated_at = now()
  where user_id = p_user_id;
  update public.profiles
  set wealth_xp = wxp, wealth_level = wl, charm_xp = cxp, charm_level = cl, updated_at = now()
  where id = p_user_id;
end;
$$;
revoke all on function public.sync_user_levels(uuid) from public, anon, authenticated;
update public.saki_account_modules m
set wealth_xp = coalesce((select sum(g.total_price) from public.room_gifts g where g.sender_id = m.user_id), 0),
    charm_xp = coalesce((select sum(g.total_price) from public.room_gifts g where g.recipient_id = m.user_id), 0),
    updated_at = now();
do $$
declare r record;
begin
  for r in select user_id from public.saki_account_modules loop
    perform public.sync_user_levels(r.user_id);
  end loop;
end;
$$;
create or replace function public.award_room_gift_wealth_xp()
returns trigger
language plpgsql security definer
set search_path = pg_catalog, public, pg_temp
as $$
declare expected_xp bigint; current_xp bigint;
begin
  select coalesce(sum(total_price), 0) into expected_xp
  from public.room_gifts where sender_id = new.sender_id;
  select wealth_xp into current_xp
  from public.saki_account_modules where user_id = new.sender_id for update;
  if coalesce(current_xp, 0) < expected_xp then
    update public.saki_account_modules
    set wealth_xp = expected_xp, updated_at = now()
    where user_id = new.sender_id;
    perform public.sync_user_levels(new.sender_id);
  end if;
  return new;
end;
$$;
revoke all on function public.award_room_gift_wealth_xp() from public, anon, authenticated;
drop trigger if exists trg_luck_gift_wealth_xp on public.room_gifts;
drop trigger if exists trg_room_gift_wealth_xp on public.room_gifts;
create trigger trg_room_gift_wealth_xp after insert on public.room_gifts
  for each row execute function public.award_room_gift_wealth_xp();

-- Source feature: a single active room per owner.
create unique index if not exists rooms_one_per_owner_uidx on public.rooms(owner_id);
create or replace function public.saki_get_or_validate_room(p_room_id text)
returns public.rooms
language sql stable security invoker
set search_path = pg_catalog, public, pg_temp
as $$
  select r from public.rooms r
  where r.room_id = p_room_id and r.is_active = true
  limit 1;
$$;
revoke all on function public.saki_get_or_validate_room(text) from public, anon;
grant execute on function public.saki_get_or_validate_room(text) to authenticated;
