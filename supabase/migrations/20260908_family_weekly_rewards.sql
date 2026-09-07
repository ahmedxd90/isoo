-- SAKI family weekly support settlement and task seeding for newly created families.
create or replace function public.create_family(
  p_name text, p_alias text, p_description text, p_avatar_url text default null
) returns public.families
language plpgsql security definer set search_path=public as $$
declare result public.families;
begin
  if exists(select 1 from family_members where user_id=auth.uid() and status='active') then raise exception 'already_in_family'; end if;
  if char_length(trim(p_alias)) < 5 or trim(p_alias) !~ '^[[:alnum:]_\u0600-\u06FF]+$' then raise exception 'invalid_family_alias'; end if;
  update saki_account_modules set gold_coins=gold_coins-500000,updated_at=now() where user_id=auth.uid() and gold_coins>=500000;
  if not found then raise exception 'insufficient_gold'; end if;
  insert into families(owner_id,name,family_alias,description,avatar_url) values(auth.uid(),trim(p_name),trim(p_alias),trim(coalesce(p_description,'')),nullif(trim(p_avatar_url),'')) returning * into result;
  insert into family_members(family_id,user_id,role) values(result.id,auth.uid(),'owner');
  insert into family_tasks(family_id,task_key,title,target,daily_target,reward_points,period) values
    (result.id,'gift_10000','إرسال هدية بقيمة 10,000 ذهبية',10000,10000,2000,'daily'),
    (result.id,'private_5','إرسال 5 رسائل خاصة لأصدقاء العائلة',5,5,3000,'daily'),
    (result.id,'room_messages_5','إرسال 5 رسائل في غرفة العائلة',5,5,1000,'daily'),
    (result.id,'gift_100000','إرسال هدية بقيمة 100,000 ذهبية',100000,100000,10000,'daily'),
    (result.id,'post','نشر منشور في اللحظات',1,1,1000,'daily'),
    (result.id,'reel','نشر ريلز',1,1,1000,'daily');
  return result;
exception when unique_violation then raise exception 'family_alias_taken';
end; $$;
grant execute on function public.create_family(text,text,text,text) to authenticated;

alter table public.family_weekly_rewards add column if not exists owner_bonus_gold bigint not null default 0;
create or replace function public.settle_family_weekly_rewards(p_family_id uuid)
returns bigint language plpgsql security definer set search_path=public as $$
declare family_row public.families%rowtype; week_date date:=date_trunc('week',now())::date; row_data record; inserted_count integer:=0; total_sent bigint:=0; owner_bonus bigint:=0; previous_bonus bigint:=0;
begin
  select * into family_row from public.families where id=p_family_id and owner_id=auth.uid() for update;
  if family_row.id is null then raise exception 'family_owner_required'; end if;
  select coalesce(sum(g.total_price),0)::bigint into total_sent from public.family_members fm left join public.rooms r on r.owner_id=family_row.owner_id and r.is_active=true left join public.room_gifts g on g.room_id=r.id and g.sender_id=fm.user_id and g.created_at>=date_trunc('week',now()) where fm.family_id=p_family_id and fm.status='active';
  for row_data in select p.id user_id,coalesce(sum(g.total_price),0)::bigint sent_gold,row_number() over(order by coalesce(sum(g.total_price),0) desc)::int rank from public.family_members fm join public.profiles p on p.id=fm.user_id left join public.rooms r on r.owner_id=family_row.owner_id and r.is_active=true left join public.room_gifts g on g.room_id=r.id and g.sender_id=p.id and g.created_at>=date_trunc('week',now()) where fm.family_id=p_family_id and fm.status='active' group by p.id order by 2 desc limit 20 loop
    if row_data.sent_gold>0 then
      insert into public.family_weekly_rewards(family_id,week_start,user_id,sent_gold,reward_gold,rank) values(p_family_id,week_date,row_data.user_id,row_data.sent_gold,floor(row_data.sent_gold*0.05)::bigint,row_data.rank) on conflict(family_id,week_start,user_id) do nothing;
      if found then update public.saki_account_modules set gold_coins=gold_coins+floor(row_data.sent_gold*0.05)::bigint,updated_at=now() where user_id=row_data.user_id; inserted_count:=inserted_count+1; end if;
    end if;
  end loop;
  owner_bonus:=floor(total_sent*0.10)::bigint;
  select coalesce(owner_bonus_gold,0) into previous_bonus from public.family_weekly_rewards where family_id=p_family_id and week_start=week_date and user_id=family_row.owner_id;
  insert into public.family_weekly_rewards(family_id,week_start,user_id,sent_gold,reward_gold,rank,owner_bonus_gold) values(p_family_id,week_date,family_row.owner_id,total_sent,0,0,owner_bonus) on conflict(family_id,week_start,user_id) do update set owner_bonus_gold=excluded.owner_bonus_gold,sent_gold=greatest(public.family_weekly_rewards.sent_gold,excluded.sent_gold);
  if previous_bonus=0 and owner_bonus>0 then update public.saki_account_modules set gold_coins=gold_coins+owner_bonus,updated_at=now() where user_id=family_row.owner_id; end if;
  return inserted_count;
end; $$;
grant execute on function public.settle_family_weekly_rewards(uuid) to authenticated;
