-- Restore authenticated access to the social tables while keeping writes scoped
-- to the authenticated owner. This project starts with an empty user dataset.

alter table public.profiles enable row level security;
alter table public.follows enable row level security;
alter table public.post_comments enable row level security;
alter table public.post_likes enable row level security;
alter table public.reels enable row level security;
alter table public.reel_comments enable row level security;
alter table public.reel_likes enable row level security;
alter table public.host_agency_payout_requests enable row level security;

-- Profiles are readable to signed-in users for the app's search, room, and
-- social UI. Direct changes are restricted to editable profile columns only.
drop policy if exists saki_profiles_read_authenticated on public.profiles;
create policy saki_profiles_read_authenticated
  on public.profiles for select to authenticated using (true);
drop policy if exists saki_profiles_update_own on public.profiles;
create policy saki_profiles_update_own
  on public.profiles for update to authenticated
  using (id = (select auth.uid()))
  with check (id = (select auth.uid()));

-- The app displays follower counts and lists, so signed-in users may read the
-- graph; a user can only create or remove their own outgoing follow edges.
drop policy if exists saki_follows_read_authenticated on public.follows;
create policy saki_follows_read_authenticated
  on public.follows for select to authenticated using (true);
drop policy if exists saki_follows_insert_own on public.follows;
create policy saki_follows_insert_own
  on public.follows for insert to authenticated
  with check (follower_id = (select auth.uid()));
drop policy if exists saki_follows_delete_own on public.follows;
create policy saki_follows_delete_own
  on public.follows for delete to authenticated
  using (follower_id = (select auth.uid()));

-- Comments and likes are visible only when the parent post is visible under
-- its own RLS policy. Users can create/delete only their own interactions.
drop policy if exists saki_post_comments_read_visible on public.post_comments;
create policy saki_post_comments_read_visible
  on public.post_comments for select to authenticated
  using (exists (
    select 1 from public.posts p where p.id = post_comments.post_id
  ));
drop policy if exists saki_post_comments_insert_own on public.post_comments;
create policy saki_post_comments_insert_own
  on public.post_comments for insert to authenticated
  with check (
    user_id = (select auth.uid())
    and exists (select 1 from public.posts p where p.id = post_comments.post_id)
  );
drop policy if exists saki_post_comments_delete_own on public.post_comments;
create policy saki_post_comments_delete_own
  on public.post_comments for delete to authenticated
  using (user_id = (select auth.uid()));

drop policy if exists saki_post_likes_read_visible on public.post_likes;
create policy saki_post_likes_read_visible
  on public.post_likes for select to authenticated
  using (exists (
    select 1 from public.posts p where p.id = post_likes.post_id
  ));
drop policy if exists saki_post_likes_insert_own on public.post_likes;
create policy saki_post_likes_insert_own
  on public.post_likes for insert to authenticated
  with check (
    user_id = (select auth.uid())
    and exists (select 1 from public.posts p where p.id = post_likes.post_id)
  );
drop policy if exists saki_post_likes_delete_own on public.post_likes;
create policy saki_post_likes_delete_own
  on public.post_likes for delete to authenticated
  using (user_id = (select auth.uid()));

-- Public reels are discoverable, followers-only reels require a follow edge,
-- and private reels remain visible to their author. Parent checks below inherit
-- this same visibility through RLS.
drop policy if exists saki_reels_read_visible on public.reels;
create policy saki_reels_read_visible
  on public.reels for select to authenticated
  using (
    author_id = (select auth.uid())
    or visibility = 'public'
    or (
      visibility = 'followers'
      and exists (
        select 1 from public.follows f
        where f.follower_id = (select auth.uid())
          and f.following_id = reels.author_id
      )
    )
  );
drop policy if exists saki_reels_insert_own on public.reels;
create policy saki_reels_insert_own
  on public.reels for insert to authenticated
  with check (author_id = (select auth.uid()));
drop policy if exists saki_reels_update_own on public.reels;
create policy saki_reels_update_own
  on public.reels for update to authenticated
  using (author_id = (select auth.uid()))
  with check (author_id = (select auth.uid()));
drop policy if exists saki_reels_delete_own on public.reels;
create policy saki_reels_delete_own
  on public.reels for delete to authenticated
  using (author_id = (select auth.uid()));

drop policy if exists saki_reel_comments_read_visible on public.reel_comments;
create policy saki_reel_comments_read_visible
  on public.reel_comments for select to authenticated
  using (exists (
    select 1 from public.reels r where r.id = reel_comments.reel_id
  ));
drop policy if exists saki_reel_comments_insert_own on public.reel_comments;
create policy saki_reel_comments_insert_own
  on public.reel_comments for insert to authenticated
  with check (
    user_id = (select auth.uid())
    and exists (select 1 from public.reels r where r.id = reel_comments.reel_id)
  );
drop policy if exists saki_reel_comments_delete_own on public.reel_comments;
create policy saki_reel_comments_delete_own
  on public.reel_comments for delete to authenticated
  using (user_id = (select auth.uid()));

drop policy if exists saki_reel_likes_read_visible on public.reel_likes;
create policy saki_reel_likes_read_visible
  on public.reel_likes for select to authenticated
  using (exists (
    select 1 from public.reels r where r.id = reel_likes.reel_id
  ));
drop policy if exists saki_reel_likes_insert_own on public.reel_likes;
create policy saki_reel_likes_insert_own
  on public.reel_likes for insert to authenticated
  with check (
    user_id = (select auth.uid())
    and exists (select 1 from public.reels r where r.id = reel_likes.reel_id)
  );
drop policy if exists saki_reel_likes_delete_own on public.reel_likes;
create policy saki_reel_likes_delete_own
  on public.reel_likes for delete to authenticated
  using (user_id = (select auth.uid()));

-- This legacy-compatible payout queue is read-only in the client. Owners see
-- their own rows; only SAKI super-admins can review the whole queue.
drop policy if exists saki_host_agency_payout_requests_read on public.host_agency_payout_requests;
create policy saki_host_agency_payout_requests_read
  on public.host_agency_payout_requests for select to authenticated
  using (
    host_id = (select auth.uid())
    or public.is_saki_super_admin()
  );

-- Remove broad/default table grants, especially profile escalation paths, and
-- grant only the operations the Flutter client actually uses.
revoke all privileges on table public.profiles from public, anon, authenticated;
grant select on table public.profiles to authenticated;
grant update (username, display_name, bio, country, country_code, avatar_url, updated_at)
  on table public.profiles to authenticated;

do $$
declare
  t text;
begin
  foreach t in array array[
    'follows', 'post_comments', 'post_likes', 'reels',
    'reel_comments', 'reel_likes', 'host_agency_payout_requests'
  ] loop
    execute format('revoke all privileges on table public.%I from public, anon, authenticated', t);
  end loop;
end;
$$;

grant select, insert, delete on table public.follows to authenticated;
grant select, insert, delete on table public.post_comments to authenticated;
grant select, insert, delete on table public.post_likes to authenticated;
grant select, insert, update, delete on table public.reels to authenticated;
grant select, insert, delete on table public.reel_comments to authenticated;
grant select, insert, delete on table public.reel_likes to authenticated;
grant select on table public.host_agency_payout_requests to authenticated;

grant all privileges on table public.profiles, public.follows, public.post_comments,
  public.post_likes, public.reels, public.reel_comments, public.reel_likes,
  public.host_agency_payout_requests to service_role;

-- A SECURITY DEFINER view bypasses the caller's RLS on its underlying tables.
-- Use invoker semantics so the families/family_members/profile/room policies apply.
alter view public.family_square set (security_invoker = true);

-- Public execution is inherited by anon and authenticated. Close every
-- SECURITY DEFINER routine by default, then expose only app RPCs and RLS helpers
-- to authenticated users. Trigger and scheduler functions continue to run as
-- their owning role and are deliberately not exposed through PostgREST.
do $$
declare
  r record;
  app_rpcs text[] := array[
    'accept_pk_battle','add_pk_points','admin_add_gold','admin_add_saki_coins',
    'admin_assign_shipping_agent','admin_ban_app','admin_create_redeem_code',
    'admin_delete_room_gift','admin_list_audit_log','admin_list_users',
    'admin_my_access','admin_redeem_codes','admin_remove_shipping_agent',
    'admin_set_family_status','admin_set_room_id','admin_set_room_presentation',
    'admin_set_saki_id','admin_set_user_role','admin_set_vip','admin_shipping_agents',
    'admin_update_user_profile','approve_family_join','claim_room_luck_bag',
    'claim_room_seat','claim_user_daily_login','clear_room_messages',
    'complete_family_task','convert_diamonds_to_gold','create_family',
    'create_private_conversation','create_room_luck_bag','end_live_broadcast',
    'enter_room','family_gift_leaderboard','family_weekly_leaderboard',
    'finish_pk_battle','get_trending_rooms','gift_vip','global_gift_room_leaderboard',
    'global_gift_user_leaderboard','is_saki_super_admin','is_shipping_agent',
    'leave_family','leave_room','leave_room_seat','purchase_vip',
    'record_user_task_event','redeem_saki_code','reject_family_join',
    'request_family_join','resolve_banner_profile','resolve_banner_room',
    'saki_admin_dashboard','saki_buffet_finish_round','saki_buffet_get_round',
    'saki_buffet_place_bet','saki_buffet_resolve_round','saki_buffet_round_leaderboard',
    'saki_get_equipped_entrance','saki_room_ban_and_remove','saki_store_buy',
    'saki_store_claim_entrance','saki_store_equip','send_room_gift',
    'send_room_luck_gift','set_luck_daily_percent','set_room_cinema_state',
    'set_room_music_state','settle_family_weekly_rewards','shipping_agent_dashboard',
    'shipping_find_user','shipping_topup_user','start_live_broadcast','start_pk_battle',
    'touch_room_presence','update_family_settings','user_badges_for_profile',
    'user_daily_login_status','user_tasks_snapshot'
  ];
  policy_helpers text[] := array[
    'is_saki_super_admin','saki_current_admin_role','saki_has_admin_permission'
  ];
begin
  for r in
    select p.oid, p.proname
    from pg_proc p
    join pg_namespace n on n.oid = p.pronamespace
    where n.nspname = 'public'
      and p.prosecdef
  loop
    execute format(
      'revoke all privileges on function %s from public, anon, authenticated',
      r.oid::regprocedure
    );
    if r.proname = any (app_rpcs) or r.proname = any (policy_helpers) then
      execute format(
        'grant execute on function %s to authenticated',
        r.oid::regprocedure
      );
    end if;
  end loop;
end;
$$;

-- Pin search_path on the remaining helper functions reported by the linter.
do $$
declare
  r record;
begin
  for r in
    select p.oid
    from pg_proc p
    join pg_namespace n on n.oid = p.pronamespace
    where n.nspname = 'public'
      and p.proname = any (array[
        'level_from_xp', 'family_level_for_points',
        'family_weekly_level_for_gold', 'get_trending_rooms',
        'is_banner_visible', 'host_agency_diamond_usd_value'
      ])
  loop
    execute format(
      'alter function %s set search_path = pg_catalog, public, pg_temp',
      r.oid::regprocedure
    );
  end loop;
end;
$$;
