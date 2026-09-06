-- Read-only Super Admin visibility for content and moderation sections.
do $$
declare t text;
begin
  foreach t in array array['posts','post_comments','reels','reel_comments','messages','notifications','follows','room_messages','room_bans','room_mutes','room_moderators','vip_transactions','gift_announcements','room_banners'] loop
    if to_regclass('public.' || t) is not null then
      execute format('drop policy if exists saki_admin_read_%I on public.%I', t, t);
      execute format('create policy saki_admin_read_%I on public.%I for select to authenticated using (public.is_saki_super_admin())', t, t);
    end if;
  end loop;
end $$;
