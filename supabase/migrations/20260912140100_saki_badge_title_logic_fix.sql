update public.badge_catalog set category='first_recharge' where badge_key='first_recharge_7500';
update public.badge_catalog set category='title_gift' where badge_key='title_gift_patron';
update public.badge_catalog set category='title_recharge' where badge_key='title_recharge_master';
update public.badge_catalog set category='title_room_owner' where badge_key='title_room_owner';
update public.badge_catalog set category='title_elite' where badge_key='title_elite_legend';

create or replace function public.evaluate_user_badges(p_user_id uuid) returns void language plpgsql security definer set search_path=public as $$
declare r record; v_value bigint; v_streak integer:=0; v_day date:=current_date; v_has boolean; v_last date; v_gifts bigint; v_recharge bigint; v_room bigint;
begin
 select max(claim_date) into v_last from public.user_daily_login_rewards where user_id=p_user_id;
 if v_last is not null then v_day:=v_last; loop select exists(select 1 from public.user_daily_login_rewards where user_id=p_user_id and claim_date=v_day) into v_has; exit when not v_has; v_streak:=v_streak+1; v_day:=v_day-1; end loop; end if;
 select coalesce(sum(total_price),0) into v_gifts from public.room_gifts where sender_id=p_user_id;
 select coalesce(sum(gold_coins),0)+coalesce((select sum(gold_coins) from public.verified_gold_recharge_events where user_id=p_user_id and verified),0) into v_recharge from public.shipping_transactions where recipient_id=p_user_id;
 select coalesce(sum(g.total_price),0) into v_room from public.room_gifts g join public.rooms rm on rm.id=g.room_id where rm.owner_id=p_user_id;
 for r in select badge_key,target,category,asset_path,name,description from public.badge_catalog where is_active loop
  v_value:=case r.category
   when 'login' then v_streak
   when 'seat' then coalesce((select sum(duration_seconds) from public.room_seat_sessions where user_id=p_user_id),0)+coalesce((select extract(epoch from(now()-joined_at))::bigint from public.room_seats where user_id=p_user_id limit 1),0)
   when 'post' then (select count(*) from public.posts where author_id=p_user_id)
   when 'reel' then (select count(*) from public.reels where author_id=p_user_id)
   when 'admin' then case when exists(select 1 from public.profiles where id=p_user_id and is_super_admin) then 1 else 0 end
   when 'gift_sent','title_gift' then v_gifts
   when 'recharge' ,'title_recharge' then v_recharge
   when 'first_recharge' then greatest(coalesce((select max(gold_coins) from public.shipping_transactions where recipient_id=p_user_id),0),coalesce((select max(gold_coins) from public.verified_gold_recharge_events where user_id=p_user_id and verified),0))
   when 'room_owner_gift','title_room_owner' then v_room
   when 'title_elite' then greatest(v_gifts,v_recharge,v_room)
   else 0 end;
  if v_value>=r.target and not exists(select 1 from public.user_badges where user_id=p_user_id and badge_key=r.badge_key) then
   insert into public.user_badges(user_id,badge_key) values(p_user_id,r.badge_key);
   insert into public.notifications(user_id,actor_id,type,badge_key,badge_asset_path,is_read,data) values(p_user_id,p_user_id,'badge_earned',r.badge_key,r.asset_path,false,jsonb_build_object('badge_key',r.badge_key,'name',r.name,'description',r.description));
  end if;
 end loop;
end; $$;
do $$ declare p record; begin for p in select id from public.profiles loop perform public.evaluate_user_badges(p.id); end loop; end $$;
