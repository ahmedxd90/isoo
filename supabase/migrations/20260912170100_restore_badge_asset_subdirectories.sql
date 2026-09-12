-- The generated badge files live in category subdirectories under assets/badges/.
update public.badge_catalog
set asset_path = case badge_key
  when 'gift_sent_1m' then 'assets/badges/gifts/gift_1m.png'
  when 'gift_sent_10m' then 'assets/badges/gifts/gift_10m.png'
  when 'gift_sent_50m' then 'assets/badges/gifts/gift_50m.png'
  when 'gift_sent_100m' then 'assets/badges/gifts/gift_100m.png'
  when 'first_recharge_7500' then 'assets/badges/recharge/first_7500.png'
  when 'recharge_1m' then 'assets/badges/recharge/recharge_1m.png'
  when 'recharge_10m' then 'assets/badges/recharge/recharge_10m.png'
  when 'recharge_50m' then 'assets/badges/recharge/recharge_50m.png'
  when 'recharge_100m' then 'assets/badges/recharge/recharge_100m.png'
  when 'room_owner_gift_1m' then 'assets/badges/rooms/room_gift_1m.png'
  when 'room_owner_gift_10m' then 'assets/badges/rooms/room_gift_10m.png'
  when 'room_owner_gift_50m' then 'assets/badges/rooms/room_gift_50m.png'
  when 'room_owner_gift_100m' then 'assets/badges/rooms/room_gift_100m.png'
  when 'title_gift_patron' then 'assets/badges/titles/gift_patron.png'
  when 'title_recharge_master' then 'assets/badges/titles/recharge_master.png'
  when 'title_room_owner' then 'assets/badges/titles/room_owner.png'
  when 'title_elite_legend' then 'assets/badges/titles/elite_legend.png'
  else asset_path
end
where badge_key in (
  'gift_sent_1m','gift_sent_10m','gift_sent_50m','gift_sent_100m',
  'first_recharge_7500','recharge_1m','recharge_10m','recharge_50m','recharge_100m',
  'room_owner_gift_1m','room_owner_gift_10m','room_owner_gift_50m','room_owner_gift_100m',
  'title_gift_patron','title_recharge_master','title_room_owner','title_elite_legend'
);
