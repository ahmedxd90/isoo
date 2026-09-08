create table if not exists public.user_task_definitions (
  task_key text primary key,
  title text not null,
  description text not null,
  target bigint not null check (target > 0),
  reward_gold bigint not null check (reward_gold > 0),
  action_route text not null default '/home',
  icon_key text not null default 'task',
  sort_order integer not null default 0,
  is_active boolean not null default true
);

create table if not exists public.user_task_progress (
  user_id uuid not null references public.profiles(id) on delete cascade,
  task_key text not null references public.user_task_definitions(task_key) on delete cascade,
  task_date date not null default current_date,
  progress bigint not null default 0 check (progress >= 0),
  completed_at timestamptz,
  claimed_at timestamptz,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  primary key (user_id, task_key, task_date)
);

create table if not exists public.user_task_reward_ledger (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references public.profiles(id) on delete cascade,
  task_key text not null references public.user_task_definitions(task_key) on delete cascade,
  reward_date date not null default current_date,
  amount bigint not null check (amount > 0),
  reward_type text not null default 'task',
  created_at timestamptz not null default now(),
  unique(user_id, task_key, reward_date, reward_type)
);

create table if not exists public.user_daily_login_rewards (
  user_id uuid not null references public.profiles(id) on delete cascade,
  claim_date date not null default current_date,
  cycle_day integer not null check (cycle_day between 1 and 7),
  amount bigint not null check (amount > 0),
  created_at timestamptz not null default now(),
  primary key (user_id, claim_date),
  unique(user_id, cycle_day, claim_date)
);

insert into public.user_task_definitions(task_key,title,description,target,reward_gold,action_route,icon_key,sort_order)
values
  ('seat_5_minutes','استخدم مقعدًا في الغرفة','ابقَ على مقعد صوتي لمدة 5 دقائق',1,100,'/rooms','seat',10),
  ('post_like','أعجب بمنشور','ضع إعجابًا على منشور جديد',1,400,'/posts','heart',20),
  ('reel_like','أعجب بريلز','ضع إعجابًا على ريلز جديد',1,150,'/reels','reel',30),
  ('private_messages_10','أرسل 10 رسائل خاصة','أرسل عشر رسائل في الدردشة الخاصة',10,300,'/messages','message',40),
  ('publish_post','انشر منشورًا','شارك منشورًا جديدًا مع المجتمع',1,500,'/posts','post',50),
  ('publish_reel','انشر ريلز','انشر مقطع ريلز جديدًا',1,600,'/reels','video',60),
  ('room_gift','أرسل هدية في الغرفة','أرسل هدية ناجحة داخل غرفة صوتية',1,300,'/rooms','gift',70)
on conflict(task_key) do update set
  title=excluded.title, description=excluded.description, target=excluded.target,
  reward_gold=excluded.reward_gold, action_route=excluded.action_route,
  icon_key=excluded.icon_key, sort_order=excluded.sort_order, is_active=true;

alter table public.user_task_definitions enable row level security;
alter table public.user_task_progress enable row level security;
alter table public.user_task_reward_ledger enable row level security;
alter table public.user_daily_login_rewards enable row level security;

drop policy if exists user_task_definitions_read on public.user_task_definitions;
create policy user_task_definitions_read on public.user_task_definitions for select to authenticated using (is_active=true);
drop policy if exists user_task_progress_own on public.user_task_progress;
create policy user_task_progress_own on public.user_task_progress for select to authenticated using (user_id=auth.uid());
drop policy if exists user_task_ledger_own on public.user_task_reward_ledger;
create policy user_task_ledger_own on public.user_task_reward_ledger for select to authenticated using (user_id=auth.uid());
drop policy if exists user_daily_login_own on public.user_daily_login_rewards;
create policy user_daily_login_own on public.user_daily_login_rewards for select to authenticated using (user_id=auth.uid());

create or replace function public._record_user_task_event(p_user_id uuid,p_task_key text,p_increment bigint default 1)
returns table(task_key text,progress bigint,target bigint,reward_gold bigint,completed boolean,claimed boolean,gold_coins bigint)
language plpgsql security definer set search_path=public as $$
declare t public.user_task_definitions%rowtype; p public.user_task_progress%rowtype; v_step bigint:=greatest(coalesce(p_increment,1),1); v_claimed boolean:=false; v_gold bigint;
begin
  select * into t from public.user_task_definitions where user_task_definitions.task_key=p_task_key and is_active=true;
  if t.task_key is null then return; end if;
  insert into public.user_task_progress(user_id,task_key,task_date,progress)
  values(p_user_id,t.task_key,current_date,0)
  on conflict(user_id,task_key,task_date) do nothing;
  select * into p from public.user_task_progress where user_id=p_user_id and user_task_progress.task_key=t.task_key and task_date=current_date for update;
  if p.claimed_at is null then
    update public.user_task_progress
      set progress=least(t.target,p.progress+v_step),
          completed_at=case when p.progress+v_step>=t.target then coalesce(p.completed_at,now()) else p.completed_at end,
          updated_at=now()
      where user_id=p_user_id and user_task_progress.task_key=t.task_key and task_date=current_date;
    select * into p from public.user_task_progress where user_id=p_user_id and user_task_progress.task_key=t.task_key and task_date=current_date;
    if p.progress>=t.target and p.claimed_at is null then
      insert into public.user_task_reward_ledger(user_id,task_key,reward_date,amount,reward_type)
      values(p_user_id,t.task_key,current_date,t.reward_gold,'task')
      on conflict(user_id,task_key,reward_date,reward_type) do nothing;
      if found then
        update public.saki_account_modules set gold_coins=gold_coins+t.reward_gold,updated_at=now() where user_id=p_user_id;
        if not found then
          insert into public.saki_account_modules(user_id,gold_coins) values(p_user_id,t.reward_gold);
        end if;
        update public.user_task_progress set claimed_at=now(),updated_at=now() where user_id=p_user_id and user_task_progress.task_key=t.task_key and task_date=current_date and claimed_at is null;
        v_claimed:=true;
      end if;
    end if;
  end if;
  select gold_coins into v_gold from public.saki_account_modules where user_id=p_user_id;
  return query select t.task_key,p.progress,t.target,t.reward_gold,p.completed_at is not null,p.claimed_at is not null,coalesce(v_gold,0);
end; $$;

create or replace function public.record_user_task_event(p_task_key text,p_increment bigint default 1)
returns table(task_key text,progress bigint,target bigint,reward_gold bigint,completed boolean,claimed boolean,gold_coins bigint)
language plpgsql security definer set search_path=public as $$ begin return query select * from public._record_user_task_event(auth.uid(),p_task_key,p_increment); end; $$;
revoke all on function public.record_user_task_event(text,bigint) from public;
grant execute on function public.record_user_task_event(text,bigint) to authenticated;

create or replace function public.claim_user_daily_login()
returns table(cycle_day integer,amount bigint,gold_coins bigint,claimed boolean)
language plpgsql security definer set search_path=public as $$
declare today date:=current_date; prev public.user_daily_login_rewards%rowtype; v_day integer; v_amount bigint; v_gold bigint; inserted boolean:=false;
begin
  if exists(select 1 from public.user_daily_login_rewards where user_id=auth.uid() and claim_date=today) then
    select cycle_day,amount into v_day,v_amount from public.user_daily_login_rewards where user_id=auth.uid() and claim_date=today;
    select gold_coins into v_gold from public.saki_account_modules where user_id=auth.uid();
    return query select v_day,v_amount,coalesce(v_gold,0),false; return;
  end if;
  select * into prev from public.user_daily_login_rewards where user_id=auth.uid() order by claim_date desc limit 1;
  if prev.claim_date=today-1 then v_day:=case when prev.cycle_day=7 then 1 else prev.cycle_day+1 end; else v_day:=1; end if;
  v_amount:=case v_day when 1 then 1000 when 2 then 100 when 3 then 400 when 4 then 600 when 5 then 700 when 6 then 2500 else 5000 end;
  insert into public.user_daily_login_rewards(user_id,claim_date,cycle_day,amount) values(auth.uid(),today,v_day,v_amount) on conflict do nothing;
  if found then
    update public.saki_account_modules set gold_coins=gold_coins+v_amount,updated_at=now() where user_id=auth.uid();
    if not found then insert into public.saki_account_modules(user_id,gold_coins) values(auth.uid(),v_amount); end if;
    inserted:=true;
  end if;
  select gold_coins into v_gold from public.saki_account_modules where user_id=auth.uid();
  return query select v_day,v_amount,coalesce(v_gold,0),inserted;
end; $$;
revoke all on function public.claim_user_daily_login() from public;
grant execute on function public.claim_user_daily_login() to authenticated;

create or replace function public.user_tasks_snapshot()
returns table(task_key text,title text,description text,target bigint,reward_gold bigint,action_route text,icon_key text,sort_order integer,progress bigint,completed boolean,claimed boolean)
language sql security definer set search_path=public as $$
  select d.task_key,d.title,d.description,d.target,d.reward_gold,d.action_route,d.icon_key,d.sort_order,
    coalesce(p.progress,0),coalesce(p.completed_at is not null,false),coalesce(p.claimed_at is not null,false)
  from public.user_task_definitions d left join public.user_task_progress p on p.task_key=d.task_key and p.user_id=auth.uid() and p.task_date=current_date
  where d.is_active=true order by d.sort_order;
$$;
revoke all on function public.user_tasks_snapshot() from public;
grant execute on function public.user_tasks_snapshot() to authenticated;

create or replace function public.user_task_post_like() returns trigger language plpgsql security definer set search_path=public as $$ begin perform public._record_user_task_event(new.user_id,'post_like',1); return new; end; $$;
create or replace function public.user_task_reel_like() returns trigger language plpgsql security definer set search_path=public as $$ begin perform public._record_user_task_event(new.user_id,'reel_like',1); return new; end; $$;
create or replace function public.user_task_message() returns trigger language plpgsql security definer set search_path=public as $$ begin perform public._record_user_task_event(new.sender_id,'private_messages_10',1); return new; end; $$;
create or replace function public.user_task_post() returns trigger language plpgsql security definer set search_path=public as $$ begin perform public._record_user_task_event(new.author_id,'publish_post',1); return new; end; $$;
create or replace function public.user_task_reel() returns trigger language plpgsql security definer set search_path=public as $$ begin perform public._record_user_task_event(new.author_id,'publish_reel',1); return new; end; $$;
create or replace function public.user_task_gift() returns trigger language plpgsql security definer set search_path=public as $$ begin perform public._record_user_task_event(new.sender_id,'room_gift',1); return new; end; $$;

drop trigger if exists user_task_post_like_trigger on public.post_likes;
create trigger user_task_post_like_trigger after insert on public.post_likes for each row execute function public.user_task_post_like();
drop trigger if exists user_task_reel_like_trigger on public.reel_likes;
create trigger user_task_reel_like_trigger after insert on public.reel_likes for each row execute function public.user_task_reel_like();
drop trigger if exists user_task_message_trigger on public.messages;
create trigger user_task_message_trigger after insert on public.messages for each row execute function public.user_task_message();
drop trigger if exists user_task_post_trigger on public.posts;
create trigger user_task_post_trigger after insert on public.posts for each row execute function public.user_task_post();
drop trigger if exists user_task_reel_trigger on public.reels;
create trigger user_task_reel_trigger after insert on public.reels for each row execute function public.user_task_reel();
drop trigger if exists user_task_gift_trigger on public.room_gifts;
create trigger user_task_gift_trigger after insert on public.room_gifts for each row execute function public.user_task_gift();
