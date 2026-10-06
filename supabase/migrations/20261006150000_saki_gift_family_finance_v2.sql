-- SAKI financial rules v2: 30% recipient diamonds, sender luck x2 reward,
-- seat-session gift totals, and family-organizer shipping transfers.

alter table public.room_seats
  add column if not exists session_gold_received bigint not null default 0,
  add column if not exists session_started_at timestamptz not null default now();

create or replace function public.saki_credit_seat_session_gold()
returns trigger
language plpgsql security definer set search_path=public
as $$
begin
  update public.room_seats
     set session_gold_received = session_gold_received + greatest(coalesce(new.total_price,0),0)
   where room_id = new.room_id and user_id = new.recipient_id;
  return new;
end;
$$;

drop trigger if exists trg_saki_credit_seat_session_gold on public.room_gifts;
create trigger trg_saki_credit_seat_session_gold
after insert on public.room_gifts
for each row execute function public.saki_credit_seat_session_gold();

-- Replace the authoritative ordinary-gift RPC with a 30% recipient rule.
create or replace function public.send_room_gift(
  p_room_id uuid, p_recipient_id uuid, p_gift_id uuid, p_quantity integer default 1
)
returns table(gold_coins bigint, gift_name text, total_price bigint, recipient_diamonds bigint)
language plpgsql security definer set search_path=public as $$
declare
  g public.room_gift_catalog%rowtype;
  v_total bigint;
  v_reward bigint;
  v_sender_ok boolean;
  v_recipient_ok boolean;
begin
  if auth.uid() is null then raise exception 'not_authenticated'; end if;
  if p_quantity is null or p_quantity < 1 or p_quantity > 99 then raise exception 'invalid_quantity'; end if;
  select * into g from public.room_gift_catalog where id=p_gift_id and is_active=true;
  if g.id is null then raise exception 'gift_not_found'; end if;
  select exists(select 1 from public.room_members where room_id=p_room_id and user_id=auth.uid()) into v_sender_ok;
  select exists(select 1 from public.room_members where room_id=p_room_id and user_id=p_recipient_id) into v_recipient_ok;
  if not v_sender_ok then raise exception 'sender_room_member_required'; end if;
  if not v_recipient_ok and p_recipient_id <> auth.uid() then raise exception 'room_member_required'; end if;
  v_total := g.price * p_quantity;
  v_reward := floor(v_total * 0.30);
  update public.saki_account_modules m
     set gold_coins=m.gold_coins-v_total, wealth_xp=m.wealth_xp+v_total, updated_at=now()
   where m.user_id=auth.uid() and m.gold_coins>=v_total;
  if not found then raise exception 'insufficient_gold'; end if;
  insert into public.saki_account_modules(user_id,diamonds,charm_xp)
    values(p_recipient_id,v_reward,v_total)
    on conflict(user_id) do update set
      diamonds=public.saki_account_modules.diamonds+excluded.diamonds,
      charm_xp=public.saki_account_modules.charm_xp+excluded.charm_xp,
      updated_at=now();
  insert into public.room_gifts(room_id,sender_id,recipient_id,gift_id,quantity,total_price,recipient_diamonds)
    values(p_room_id,auth.uid(),p_recipient_id,p_gift_id,p_quantity,v_total,v_reward);
  insert into public.room_gift_inventory(user_id,gift_id,quantity)
    values(p_recipient_id,p_gift_id,p_quantity)
    on conflict(user_id,gift_id) do update set quantity=public.room_gift_inventory.quantity+excluded.quantity;
  insert into public.gift_announcements(room_id,sender_id,recipient_id,gift_id,total_price,recipient_diamonds)
    values(p_room_id,auth.uid(),p_recipient_id,p_gift_id,v_total,v_reward);
  perform public.sync_user_levels(auth.uid());
  if p_recipient_id <> auth.uid() then perform public.sync_user_levels(p_recipient_id); end if;
  return query select m.gold_coins,g.name,v_total,v_reward from public.saki_account_modules m where m.user_id=auth.uid();
end; $$;

-- Luck gift: recipient gets 30% diamonds; sender receives the calculated luck
-- multiplier doubled, atomically, and the announced reward remains server truth.
create or replace function public.send_room_luck_gift(
  p_room_id uuid, p_recipient_id uuid, p_gift_id uuid, p_quantity integer default 1
)
returns table(gold_coins bigint,gift_name text,gift_price bigint,multiplier integer,reward_gold bigint,win_percent smallint,announcement_id uuid)
language plpgsql security definer set search_path=public as $$
declare
  g public.room_gift_catalog%rowtype;
  sender_profile public.profiles%rowtype;
  recipient_profile public.profiles%rowtype;
  r public.rooms%rowtype;
  v_total bigint;
  v_recipient_diamonds bigint;
  v_reward bigint:=0;
  v_multiplier integer:=1;
  v_win_percent smallint;
  v_roll numeric;
  v_announcement uuid;
  v_payload jsonb;
  v_balance bigint;
begin
  if auth.uid() is null then raise exception 'not_authenticated'; end if;
  if p_quantity is null or p_quantity<1 or p_quantity>99 then raise exception 'invalid_quantity'; end if;
  select * into g from public.room_gift_catalog where id=p_gift_id and category='luck' and is_active=true;
  if g.id is null then raise exception 'luck_gift_not_found'; end if;
  if not exists(select 1 from public.room_members where room_id=p_room_id and user_id=auth.uid()) then raise exception 'sender_room_member_required'; end if;
  if not exists(select 1 from public.room_members where room_id=p_room_id and user_id=p_recipient_id) and p_recipient_id<>auth.uid() then raise exception 'room_member_required'; end if;
  select * into r from public.rooms where id=p_room_id;
  select * into sender_profile from public.profiles where id=auth.uid();
  select * into recipient_profile from public.profiles where id=p_recipient_id;
  select coalesce((select s.win_percent from public.luck_daily_settings s where s.luck_date=current_date),38) into v_win_percent;
  v_total:=g.price*p_quantity;
  v_recipient_diamonds:=floor(v_total*0.30);
  update public.saki_account_modules m set gold_coins=m.gold_coins-v_total,updated_at=now()
    where m.user_id=auth.uid() and m.gold_coins>=v_total returning m.gold_coins into v_balance;
  if not found then raise exception 'insufficient_gold'; end if;
  v_roll:=random()*100;
  if v_roll<v_win_percent then
    v_roll:=random()*10000;
    if v_roll<6000 then v_multiplier:=5;
    elsif v_roll<8000 then v_multiplier:=10;
    elsif v_roll<9000 then v_multiplier:=50;
    elsif v_roll<9500 then v_multiplier:=100;
    elsif v_roll<9800 then v_multiplier:=250;
    elsif v_roll<9950 then v_multiplier:=500;
    else v_multiplier:=1000;
    end if;
    v_reward:=v_total*v_multiplier*2;
    update public.saki_account_modules set gold_coins=gold_coins+v_reward,updated_at=now() where user_id=auth.uid();
  end if;
  insert into public.saki_account_modules(user_id,diamonds) values(p_recipient_id,v_recipient_diamonds)
    on conflict(user_id) do update set diamonds=public.saki_account_modules.diamonds+excluded.diamonds,updated_at=now();
  insert into public.room_gifts(room_id,sender_id,recipient_id,gift_id,quantity,total_price,recipient_diamonds)
    values(p_room_id,auth.uid(),p_recipient_id,p_gift_id,p_quantity,v_total,v_recipient_diamonds);
  insert into public.room_gift_inventory(user_id,gift_id,quantity) values(p_recipient_id,p_gift_id,p_quantity)
    on conflict(user_id,gift_id) do update set quantity=public.room_gift_inventory.quantity+excluded.quantity;
  v_payload:=jsonb_build_object('event_type','luck_multiplier','gift_id',g.id,'icon',g.icon,'thumbnail_url',g.icon,'media_url',g.media_url,'media_type',g.media_type,'name',g.name,'category','luck','recipient_id',p_recipient_id,'sender_id',auth.uid(),'sender_username',sender_profile.username,'sender_avatar_url',sender_profile.avatar_url,'recipient_username',recipient_profile.username,'recipient_avatar_url',recipient_profile.avatar_url,'room_id',p_room_id,'room_name',r.name,'gift_price',v_total,'multiplier',v_multiplier,'reward_gold',v_reward,'recipient_diamonds',v_recipient_diamonds,'win_percent',v_win_percent,'flying_luck_banner',v_multiplier>1);
  if v_multiplier>1 then
    insert into public.gift_announcements(room_id,sender_id,recipient_id,gift_id,total_price,recipient_diamonds,event_type,multiplier,reward_gold,gift_price)
      values(p_room_id,auth.uid(),p_recipient_id,p_gift_id,v_total,v_recipient_diamonds,'luck_multiplier',v_multiplier,v_reward,v_total) returning id into v_announcement;
    insert into public.room_messages(room_id,sender_id,body,message_type,payload)
      values(p_room_id,auth.uid(),format('%s حصل على هدية الحظ ×%s والمُرسل حصل على %s عملة ذهبية',recipient_profile.username,v_multiplier,v_reward),'luck_multiplier',v_payload);
  else
    insert into public.room_messages(room_id,sender_id,body,message_type,payload) values(p_room_id,auth.uid(),format('أرسل هدية حظ %s',g.name),'gift',v_payload);
  end if;
  return query select v_balance,g.name,v_total,v_multiplier,v_reward,v_win_percent,v_announcement;
end; $$;

-- Family organizer can select an active family member as the source and a real
-- shipping agent as recipient. Exact requested packages only.
create table if not exists public.family_diamond_shipping_transfers(
  id uuid primary key default gen_random_uuid(), family_id uuid not null references public.families(id) on delete cascade,
  source_user_id uuid not null references public.profiles(id), agent_id uuid not null references public.profiles(id),
  diamonds bigint not null, usd_amount numeric(12,2) not null, saki_coins bigint not null,
  owner_commission_diamonds bigint not null default 0, created_at timestamptz not null default now()
);

create or replace function public.search_shipping_agents(p_query text default '')
returns table(user_id uuid,username text,saki_id bigint,avatar_url text)
language sql security definer set search_path=public as $$
  select p.id,coalesce(p.display_name,p.username),p.saki_id,p.avatar_url
  from public.shipping_agents a join public.profiles p on p.id=a.user_id
  where a.is_active=true and (coalesce(trim(p_query),'')='' or p.username ilike '%'||trim(p_query)||'%' or p.display_name ilike '%'||trim(p_query)||'%' or p.saki_id::text=trim(p_query))
  order by coalesce(p.display_name,p.username) limit 30;
$$;

create or replace function public.transfer_family_diamonds_to_agent(p_family_id uuid,p_source_user_id uuid,p_agent_id uuid,p_diamonds bigint)
returns jsonb language plpgsql security definer set search_path=public as $$
declare v_usd numeric(12,2); v_saki bigint; v_owner uuid; v_commission bigint; v_tx uuid; v_name text;
begin
  select owner_id into v_owner from public.families where id=p_family_id and owner_id=auth.uid();
  if v_owner is null then raise exception 'family_organizer_required'; end if;
  if not exists(select 1 from public.family_members where family_id=p_family_id and user_id=p_source_user_id and status='active') then raise exception 'family_member_required'; end if;
  if not public.is_shipping_agent(p_agent_id) then raise exception 'shipping_agent_required'; end if;
  case p_diamonds when 13000000 then v_usd:=10; v_saki:=10; when 26000000 then v_usd:=20; v_saki:=20; when 50000000 then v_usd:=40; v_saki:=40; when 100000000 then v_usd:=80; v_saki:=80; when 200000000 then v_usd:=160; v_saki:=160; else raise exception 'invalid_family_transfer_package'; end case;
  v_commission:=floor(p_diamonds*0.07);
  update public.saki_account_modules set diamonds=diamonds-p_diamonds,updated_at=now() where user_id=p_source_user_id and diamonds>=p_diamonds;
  if not found then raise exception 'insufficient_diamonds'; end if;
  update public.saki_account_modules set diamonds=diamonds+v_commission,updated_at=now() where user_id=v_owner;
  update public.shipping_agents set saki_coins=saki_coins+v_saki,updated_at=now() where user_id=p_agent_id and is_active=true;
  if not found then raise exception 'shipping_agent_not_found'; end if;
  insert into public.family_diamond_shipping_transfers(family_id,source_user_id,agent_id,diamonds,usd_amount,saki_coins,owner_commission_diamonds) values(p_family_id,p_source_user_id,p_agent_id,p_diamonds,v_usd,v_saki,v_commission) returning id into v_tx;
  select coalesce(display_name,username,'منظم العائلة') into v_name from public.profiles where id=auth.uid();
  insert into public.notifications(user_id,actor_id,type,entity_id,is_read,data) values(p_source_user_id,auth.uid(),'family_diamond_transfer',v_tx,false,jsonb_build_object('diamonds',p_diamonds,'usd',v_usd,'agent_id',p_agent_id,'message','تم تحويل الماس إلى وكيل الشحن')::text);
  insert into public.notifications(user_id,actor_id,type,entity_id,is_read,data) values(p_agent_id,auth.uid(),'family_diamond_received',v_tx,false,jsonb_build_object('diamonds',p_diamonds,'usd',v_usd,'saki_coins',v_saki,'family_id',p_family_id,'message','استلمت تحويل الماس من العائلة')::text);
  insert into public.notifications(user_id,actor_id,type,entity_id,is_read,data) values(v_owner,auth.uid(),'family_owner_commission',v_tx,false,jsonb_build_object('diamonds',v_commission,'family_id',p_family_id,'message','تمت إضافة عمولة 7% لمالك العائلة')::text);
  return jsonb_build_object('transaction_id',v_tx,'diamonds',p_diamonds,'usd',v_usd,'saki_coins',v_saki,'owner_commission_diamonds',v_commission);
end; $$;

revoke all on function public.search_shipping_agents(text),public.transfer_family_diamonds_to_agent(uuid,uuid,uuid,bigint) from public,anon;
grant execute on function public.search_shipping_agents(text),public.transfer_family_diamonds_to_agent(uuid,uuid,uuid,bigint) to authenticated;
