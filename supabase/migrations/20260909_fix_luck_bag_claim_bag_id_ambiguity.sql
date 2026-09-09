create or replace function public.claim_room_luck_bag(p_bag_id uuid)
returns table(bag_id uuid,amount_gold bigint,claimed_count integer,remaining_gold bigint,status text)
language plpgsql security definer set search_path=public as $$
declare
  v_bag public.room_luck_bags;
  v_amount bigint;
  v_left_slots integer;
begin
  select lb.* into v_bag from public.room_luck_bags as lb where lb.id=p_bag_id for update;
  if v_bag.id is null then raise exception 'luck_bag_not_found'; end if;
  if not exists(select 1 from public.room_members as rm where rm.room_id=v_bag.room_id and rm.user_id=auth.uid()) then raise exception 'not_room_member'; end if;
  if v_bag.expires_at<=now() or v_bag.status<>'open' then raise exception 'luck_bag_closed'; end if;
  if exists(select 1 from public.room_luck_bag_claims as cl where cl.bag_id=v_bag.id and cl.user_id=auth.uid()) then raise exception 'luck_bag_already_claimed'; end if;
  v_left_slots := v_bag.recipient_limit-v_bag.claimed_count;
  if v_left_slots<=0 or v_bag.remaining_gold<=0 then raise exception 'luck_bag_empty'; end if;
  if v_left_slots=1 then v_amount:=v_bag.remaining_gold; else v_amount:=greatest(1,least(v_bag.remaining_gold-(v_left_slots-1),floor(random()*((v_bag.remaining_gold/v_left_slots)*2))+1)); end if;
  insert into public.room_luck_bag_claims as cl(bag_id,user_id,amount_gold) values(v_bag.id,auth.uid(),v_amount);
  update public.saki_account_modules as am set gold_coins=am.gold_coins+v_amount,updated_at=now() where am.user_id=auth.uid();
  update public.room_luck_bags as lb set claimed_count=lb.claimed_count+1,remaining_gold=lb.remaining_gold-v_amount,status=case when lb.claimed_count+1>=lb.recipient_limit or lb.remaining_gold-v_amount<=0 then 'empty' else 'open' end where lb.id=v_bag.id returning lb.* into v_bag;
  return query select v_bag.id,v_amount,v_bag.claimed_count,v_bag.remaining_gold,v_bag.status;
end; $$;
revoke all on function public.claim_room_luck_bag(uuid) from public;
grant execute on function public.claim_room_luck_bag(uuid) to authenticated;
