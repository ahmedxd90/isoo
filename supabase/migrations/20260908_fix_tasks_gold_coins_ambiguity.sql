create or replace function public._record_user_task_event(p_user_id uuid, p_task_key text, p_increment bigint default 1)
returns table(task_key text, progress bigint, target bigint, reward_gold bigint, completed boolean, claimed boolean, gold_coins bigint)
language plpgsql security definer set search_path = public
as $$
declare
  t public.user_task_definitions%rowtype;
  p public.user_task_progress%rowtype;
  v_step bigint := greatest(coalesce(p_increment, 1), 1);
  v_gold bigint;
begin
  select d.* into t from public.user_task_definitions d
    where d.task_key = p_task_key and d.is_active = true;
  if t.task_key is null then return; end if;
  insert into public.user_task_progress(user_id, task_key, task_date, progress)
    values (p_user_id, t.task_key, current_date, 0)
    on conflict (user_id, task_key, task_date) do nothing;
  select pr.* into p from public.user_task_progress pr
    where pr.user_id = p_user_id and pr.task_key = t.task_key and pr.task_date = current_date for update;
  if p.claimed_at is null then
    update public.user_task_progress pr
      set progress = least(t.target, p.progress + v_step),
          completed_at = case when p.progress + v_step >= t.target then coalesce(p.completed_at, now()) else p.completed_at end,
          updated_at = now()
      where pr.user_id = p_user_id and pr.task_key = t.task_key and pr.task_date = current_date;
    select pr.* into p from public.user_task_progress pr
      where pr.user_id = p_user_id and pr.task_key = t.task_key and pr.task_date = current_date;
    if p.progress >= t.target and p.claimed_at is null then
      insert into public.user_task_reward_ledger(user_id, task_key, reward_date, amount, reward_type)
        values (p_user_id, t.task_key, current_date, t.reward_gold, 'task')
        on conflict (user_id, task_key, reward_date, reward_type) do nothing;
      if found then
        update public.saki_account_modules m
          set gold_coins = m.gold_coins + t.reward_gold, updated_at = now()
          where m.user_id = p_user_id;
        if not found then
          insert into public.saki_account_modules(user_id, gold_coins) values (p_user_id, t.reward_gold);
        end if;
        update public.user_task_progress pr set claimed_at = now(), updated_at = now()
          where pr.user_id = p_user_id and pr.task_key = t.task_key and pr.task_date = current_date and pr.claimed_at is null;
      end if;
    end if;
  end if;
  select m.gold_coins into v_gold from public.saki_account_modules m where m.user_id = p_user_id;
  return query select t.task_key, p.progress, t.target, t.reward_gold, p.completed_at is not null, p.claimed_at is not null, coalesce(v_gold, 0);
end;
$$;

create or replace function public.claim_user_daily_login()
returns table(cycle_day integer, amount bigint, gold_coins bigint, claimed boolean)
language plpgsql security definer set search_path = public
as $$
declare
  today date := current_date;
  prev public.user_daily_login_rewards%rowtype;
  v_day integer;
  v_amount bigint;
  v_gold bigint;
  inserted boolean := false;
begin
  if exists(select 1 from public.user_daily_login_rewards r where r.user_id = auth.uid() and r.claim_date = today) then
    select r.cycle_day, r.amount into v_day, v_amount from public.user_daily_login_rewards r where r.user_id = auth.uid() and r.claim_date = today;
    select m.gold_coins into v_gold from public.saki_account_modules m where m.user_id = auth.uid();
    return query select v_day, v_amount, coalesce(v_gold, 0), false;
    return;
  end if;
  select r.* into prev from public.user_daily_login_rewards r where r.user_id = auth.uid() order by r.claim_date desc limit 1;
  if prev.claim_date = today - 1 then v_day := case when prev.cycle_day = 7 then 1 else prev.cycle_day + 1 end; else v_day := 1; end if;
  v_amount := case v_day when 1 then 1000 when 2 then 100 when 3 then 400 when 4 then 600 when 5 then 700 when 6 then 2500 else 5000 end;
  insert into public.user_daily_login_rewards(user_id, claim_date, cycle_day, amount) values (auth.uid(), today, v_day, v_amount) on conflict do nothing;
  if found then
    update public.saki_account_modules m set gold_coins = m.gold_coins + v_amount, updated_at = now() where m.user_id = auth.uid();
    if not found then insert into public.saki_account_modules(user_id, gold_coins) values (auth.uid(), v_amount); end if;
    inserted := true;
  end if;
  select m.gold_coins into v_gold from public.saki_account_modules m where m.user_id = auth.uid();
  return query select v_day, v_amount, coalesce(v_gold, 0), inserted;
end;
$$;
