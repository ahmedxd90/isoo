-- SAKI family real membership, settings, daily tasks and weekly support rewards.
alter table public.families add column if not exists announcement text not null default '';
alter table public.families add column if not exists weekly_points bigint not null default 0;
alter table public.families add column if not exists weekly_starts_at timestamptz not null default date_trunc('week', now());
alter table public.families add column if not exists updated_at timestamptz not null default now();

alter table public.family_tasks add column if not exists task_key text;
alter table public.family_tasks add column if not exists daily_target bigint not null default 1;
update public.family_tasks set task_key = coalesce(task_key, 'legacy_' || id::text), daily_target = greatest(target, 1) where task_key is null;
alter table public.family_tasks alter column task_key set not null;
create unique index if not exists family_tasks_family_key_idx on public.family_tasks(family_id, task_key);

create table if not exists public.family_task_progress (
  family_id uuid not null references public.families(id) on delete cascade,
  task_id uuid not null references public.family_tasks(id) on delete cascade,
  user_id uuid not null references public.profiles(id) on delete cascade,
  task_date date not null default current_date,
  progress bigint not null default 0,
  completed_at timestamptz,
  primary key (task_id, user_id, task_date)
);

create table if not exists public.family_weekly_rewards (
  id uuid primary key default gen_random_uuid(),
  family_id uuid not null references public.families(id) on delete cascade,
  week_start date not null,
  user_id uuid not null references public.profiles(id) on delete cascade,
  sent_gold bigint not null default 0,
  reward_gold bigint not null default 0,
  rank integer not null,
  created_at timestamptz not null default now(),
  unique(family_id, week_start, user_id)
);

alter table public.family_task_progress enable row level security;
alter table public.family_weekly_rewards enable row level security;

drop policy if exists family_task_progress_read on public.family_task_progress;
create policy family_task_progress_read on public.family_task_progress for select to authenticated using (user_id = auth.uid() or exists (select 1 from public.family_members fm where fm.family_id = family_task_progress.family_id and fm.user_id = auth.uid() and fm.status = 'active'));
drop policy if exists family_weekly_rewards_read on public.family_weekly_rewards;
create policy family_weekly_rewards_read on public.family_weekly_rewards for select to authenticated using (user_id = auth.uid() or exists (select 1 from public.families f where f.id = family_id and f.owner_id = auth.uid()));

drop policy if exists family_requests_insert on public.family_join_requests;
create policy family_requests_insert on public.family_join_requests for insert to authenticated with check (user_id = auth.uid());
drop policy if exists family_requests_update_owner on public.family_join_requests;
create policy family_requests_update_owner on public.family_join_requests for update to authenticated using (exists (select 1 from public.families f where f.id = family_id and f.owner_id = auth.uid())) with check (exists (select 1 from public.families f where f.id = family_id and f.owner_id = auth.uid()));

create or replace function public.family_level_for_points(p_points bigint)
returns integer language sql immutable as $$
  select case
    when coalesce(p_points,0) >= 500000000 then 10
    when p_points >= 250000000 then 9
    when p_points >= 150000000 then 8
    when p_points >= 100000000 then 7
    when p_points >= 50000000 then 6
    when p_points >= 25000000 then 5
    when p_points >= 15000000 then 4
    when p_points >= 10000000 then 3
    when p_points >= 5000000 then 2
    when p_points >= 2000000 then 1
    else 0
  end;
$$;

create or replace function public.update_family_settings(
  p_family_id uuid, p_name text, p_alias text, p_avatar_url text, p_announcement text
) returns public.families
language plpgsql security definer set search_path = public as $$
declare result public.families;
begin
  update public.families set
    name = trim(p_name), family_alias = trim(p_alias), avatar_url = nullif(trim(p_avatar_url),''), announcement = coalesce(p_announcement,''), updated_at = now()
  where id = p_family_id and owner_id = auth.uid()
  returning * into result;
  if result.id is null then raise exception 'family_owner_required'; end if;
  return result;
exception when unique_violation then raise exception 'family_alias_taken';
end; $$;

drop function if exists public.approve_family_join(uuid);
create or replace function public.approve_family_join(p_request_id uuid)
returns public.family_members language plpgsql security definer set search_path = public as $$
declare request public.family_join_requests%rowtype; family_row public.families%rowtype; membership public.family_members%rowtype;
begin
  select * into request from public.family_join_requests where id = p_request_id for update;
  if request.id is null then raise exception 'request_not_found'; end if;
  select * into family_row from public.families where id = request.family_id;
  if family_row.owner_id <> auth.uid() then raise exception 'family_owner_required'; end if;
  if exists (select 1 from public.family_members where user_id = request.user_id and status = 'active') then raise exception 'user_already_in_family'; end if;
  insert into public.family_members(family_id,user_id,role,status) values(request.family_id,request.user_id,'member','active')
    on conflict (family_id,user_id) do update set status='active', role='member', joined_at=now() returning * into membership;
  update public.family_join_requests set status='approved' where id=p_request_id;
  return membership;
end; $$;
grant execute on function public.approve_family_join(uuid) to authenticated;

create or replace function public.reject_family_join(p_request_id uuid)
returns void language plpgsql security definer set search_path = public as $$
declare request public.family_join_requests%rowtype;
begin
  select r.* into request from public.family_join_requests r join public.families f on f.id=r.family_id where r.id=p_request_id and f.owner_id=auth.uid();
  if request.id is null then raise exception 'family_owner_required'; end if;
  update public.family_join_requests set status='rejected' where id=p_request_id;
end; $$;
grant execute on function public.reject_family_join(uuid) to authenticated;

create or replace function public.complete_family_task(p_family_id uuid, p_task_key text, p_increment bigint default 1)
returns table(task_id uuid, progress bigint, completed boolean, family_points bigint)
language plpgsql security definer set search_path = public as $$
declare task_row public.family_tasks%rowtype; member_ok boolean; progress_row public.family_task_progress%rowtype; new_points bigint;
begin
  select exists(select 1 from public.family_members where family_id=p_family_id and user_id=auth.uid() and status='active') into member_ok;
  if not member_ok then raise exception 'family_member_required'; end if;
  select * into task_row from public.family_tasks where family_id=p_family_id and task_key=p_task_key limit 1;
  if task_row.id is null then raise exception 'family_task_not_found'; end if;
  insert into public.family_task_progress(task_id,family_id,user_id,task_date,progress)
    values(task_row.id,p_family_id,auth.uid(),current_date,0)
    on conflict (task_id,user_id,task_date) do nothing;
  select * into progress_row from public.family_task_progress where task_id=task_row.id and user_id=auth.uid() and task_date=current_date for update;
  if progress_row.completed_at is null then
    update public.family_task_progress set progress=least(task_row.daily_target,progress_row.progress+greatest(p_increment,1)), completed_at=case when progress_row.progress+greatest(p_increment,1)>=task_row.daily_target then now() else null end where task_id=task_row.id and user_id=auth.uid() and task_date=current_date returning * into progress_row;
    if progress_row.completed_at is not null then
      update public.families set points=points+task_row.reward_points, level=public.family_level_for_points(points+task_row.reward_points), weekly_points=weekly_points+task_row.reward_points where id=p_family_id returning points into new_points;
    else select points into new_points from public.families where id=p_family_id; end if;
  else select points into new_points from public.families where id=p_family_id; end if;
  return query select task_row.id, progress_row.progress, progress_row.completed_at is not null, new_points;
end; $$;
grant execute on function public.complete_family_task(uuid,text,bigint) to authenticated;

create or replace function public.family_weekly_leaderboard(p_family_id uuid)
returns table(user_id uuid, username text, avatar_url text, sent_gold bigint, rank bigint)
language sql security definer set search_path = public as $$
  select p.id,p.username,p.avatar_url,coalesce(sum(g.total_price),0)::bigint,
         row_number() over(order by coalesce(sum(g.total_price),0) desc)
  from public.family_members fm join public.profiles p on p.id=fm.user_id
  join public.families f on f.id=fm.family_id
  left join public.rooms r on r.owner_id=f.owner_id and r.is_active=true
  left join public.room_gifts g on g.room_id=r.id and g.sender_id=p.id and g.created_at >= date_trunc('week',now())
  where fm.family_id=p_family_id and fm.status='active'
  group by p.id,p.username,p.avatar_url order by 4 desc limit 20;
$$;
grant execute on function public.family_weekly_leaderboard(uuid) to authenticated;

-- Seed the requested daily tasks for every existing family; new families receive them in create_family.
insert into public.family_tasks(family_id,task_key,title,target,daily_target,reward_points,period)
select f.id,v.task_key,v.title,v.target,v.target,v.reward,'daily'
from public.families f cross join (values
 ('gift_10000','إرسال هدية بقيمة 10,000 ذهبية',10000,2000),
 ('private_5','إرسال 5 رسائل خاصة لأصدقاء العائلة',5,3000),
 ('room_messages_5','إرسال 5 رسائل في غرفة العائلة',5,1000),
 ('gift_100000','إرسال هدية بقيمة 100,000 ذهبية',100000,10000),
 ('post','نشر منشور في اللحظات',1,1000),
 ('reel','نشر ريلز',1,1000)
) v(task_key,title,target,reward)
on conflict (family_id,task_key) do update set title=excluded.title,daily_target=excluded.daily_target,reward_points=excluded.reward_points;

DO $$ BEGIN
  ALTER PUBLICATION supabase_realtime ADD TABLE public.family_join_requests;
EXCEPTION WHEN duplicate_object THEN NULL; END $$;
DO $$ BEGIN
  ALTER PUBLICATION supabase_realtime ADD TABLE public.family_members;
EXCEPTION WHEN duplicate_object THEN NULL; END $$;
