-- Love House: private relationship and invitation ledger.
-- All wallet mutations are server-side SECURITY DEFINER RPCs only.

create table if not exists public.love_relationships (
  id uuid primary key default gen_random_uuid(),
  user_a_id uuid not null references public.profiles(id) on delete cascade,
  user_b_id uuid not null references public.profiles(id) on delete cascade,
  started_at timestamptz not null default now(),
  ended_at timestamptz,
  ended_by uuid references public.profiles(id) on delete set null,
  constraint love_relationships_distinct_users check (user_a_id <> user_b_id),
  constraint love_relationships_canonical_order check (user_a_id < user_b_id)
);

create table if not exists public.love_partner_invitations (
  id uuid primary key default gen_random_uuid(),
  sender_id uuid not null references public.profiles(id) on delete cascade,
  recipient_id uuid not null references public.profiles(id) on delete cascade,
  status text not null default 'pending'
    check (status in ('pending', 'accepted', 'rejected', 'expired')),
  gold_cost bigint not null default 300000 check (gold_cost = 300000),
  created_at timestamptz not null default now(),
  expires_at timestamptz not null,
  resolved_at timestamptz,
  relationship_id uuid references public.love_relationships(id) on delete set null,
  constraint love_partner_invitations_distinct_users check (sender_id <> recipient_id)
);

create index if not exists love_relationships_user_a_active_idx
  on public.love_relationships(user_a_id) where ended_at is null;
create index if not exists love_relationships_user_b_active_idx
  on public.love_relationships(user_b_id) where ended_at is null;
create unique index if not exists love_relationships_active_user_a_uidx
  on public.love_relationships(user_a_id) where ended_at is null;
create unique index if not exists love_relationships_active_user_b_uidx
  on public.love_relationships(user_b_id) where ended_at is null;
create index if not exists love_partner_invites_sender_status_idx
  on public.love_partner_invitations(sender_id, status, created_at desc);
create index if not exists love_partner_invites_recipient_status_idx
  on public.love_partner_invitations(recipient_id, status, created_at desc);
create index if not exists love_partner_invites_expiry_idx
  on public.love_partner_invitations(expires_at) where status = 'pending';
create unique index if not exists love_partner_invites_one_pending_pair_uidx
  on public.love_partner_invitations(sender_id, recipient_id) where status = 'pending';

alter table public.love_relationships enable row level security;
alter table public.love_partner_invitations enable row level security;

drop policy if exists love_relationship_participants_read on public.love_relationships;
create policy love_relationship_participants_read
  on public.love_relationships for select to authenticated
  using (auth.uid() = user_a_id or auth.uid() = user_b_id);

drop policy if exists love_invitation_participants_read on public.love_partner_invitations;
create policy love_invitation_participants_read
  on public.love_partner_invitations for select to authenticated
  using (auth.uid() = sender_id or auth.uid() = recipient_id);

revoke all on public.love_relationships, public.love_partner_invitations
  from anon, authenticated;
grant all on public.love_relationships, public.love_partner_invitations
  to service_role;

create or replace function public._saki_refund_love_invite_gold(
  p_user_id uuid,
  p_amount bigint
)
returns bigint
language plpgsql
security definer
set search_path = public, pg_temp
as $$
declare
  v_balance bigint;
begin
  if p_amount <> 300000 then
    raise exception 'invalid_love_invite_refund_amount' using errcode = '22023';
  end if;

  insert into public.saki_account_modules as account (user_id, gold_coins, updated_at)
  values (p_user_id, p_amount, now())
  on conflict (user_id) do update
    set gold_coins = account.gold_coins + excluded.gold_coins,
        updated_at = now()
  returning gold_coins into v_balance;

  return v_balance;
end;
$$;
revoke all on function public._saki_refund_love_invite_gold(uuid, bigint)
  from public, anon, authenticated, service_role;

create or replace function public.expire_love_partner_invites()
returns integer
language plpgsql
security definer
set search_path = public, pg_temp
as $$
declare
  v_invite record;
  v_count integer := 0;
begin
  for v_invite in
    select id, sender_id, recipient_id, gold_cost
    from public.love_partner_invitations
    where status = 'pending' and expires_at <= now()
    order by expires_at
    for update skip locked
  loop
    update public.love_partner_invitations
      set status = 'expired', resolved_at = now()
      where id = v_invite.id and status = 'pending';

    if found then
      perform public._saki_refund_love_invite_gold(v_invite.sender_id, v_invite.gold_cost);
      update public.notifications
        set is_read = true,
            data = 'انتهت مهلة الدعوة، وتمت إعادة 300,000 ذهب إلى المرسل.'
        where user_id = v_invite.recipient_id
          and type = 'love_partner_invite'
          and entity_id = v_invite.id;
      insert into public.notifications (user_id, actor_id, type, entity_id, data)
        values (v_invite.sender_id, v_invite.recipient_id, 'love_partner_expired', v_invite.id,
          'انتهت مهلة دعوة بيت الحب، وتمت إعادة 300,000 ذهب إلى رصيدك.');
      v_count := v_count + 1;
    end if;
  end loop;
  return v_count;
end;
$$;
revoke all on function public.expire_love_partner_invites()
  from public, anon, authenticated;
grant execute on function public.expire_love_partner_invites() to service_role;

create or replace function public.saki_love_mutual_friends()
returns table (
  id uuid,
  username text,
  display_name text,
  avatar_url text,
  saki_id bigint
)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if auth.uid() is null then
    raise exception 'authentication_required' using errcode = '28000';
  end if;

  return query
    select p.id, p.username, p.display_name, p.avatar_url, p.saki_id
    from public.profiles p
    join public.follows outgoing
      on outgoing.following_id = p.id and outgoing.follower_id = auth.uid()
    join public.follows reciprocal
      on reciprocal.follower_id = p.id and reciprocal.following_id = auth.uid()
    where p.id <> auth.uid()
    order by coalesce(nullif(p.display_name, ''), p.username) nulls last
    limit 200;
end;
$$;
revoke all on function public.saki_love_mutual_friends()
  from public, anon;
grant execute on function public.saki_love_mutual_friends() to authenticated;

create or replace function public.saki_love_house_state()
returns jsonb
language plpgsql
security definer
set search_path = public, pg_temp
as $$
declare
  v_user uuid := auth.uid();
  v_relationship jsonb;
  v_outgoing jsonb;
  v_incoming jsonb;
  v_profile jsonb;
  v_balance bigint := 0;
begin
  if v_user is null then
    raise exception 'authentication_required' using errcode = '28000';
  end if;

  perform public.expire_love_partner_invites();

  select jsonb_build_object(
      'id', p.id,
      'username', p.username,
      'display_name', p.display_name,
      'avatar_url', p.avatar_url,
      'saki_id', p.saki_id
    )
    into v_profile
    from public.profiles p where p.id = v_user;

  select gold_coins into v_balance
    from public.saki_account_modules where user_id = v_user;
  v_balance := coalesce(v_balance, 0);

  select jsonb_build_object(
      'id', r.id,
      'started_at', r.started_at,
      'partner', jsonb_build_object(
        'id', partner.id,
        'username', partner.username,
        'display_name', partner.display_name,
        'avatar_url', partner.avatar_url,
        'saki_id', partner.saki_id
      )
    )
    into v_relationship
    from public.love_relationships r
    join public.profiles partner
      on partner.id = case when r.user_a_id = v_user then r.user_b_id else r.user_a_id end
    where r.ended_at is null and (r.user_a_id = v_user or r.user_b_id = v_user)
    order by r.started_at desc
    limit 1;

  select jsonb_build_object(
      'id', i.id, 'recipient_id', i.recipient_id, 'status', i.status,
      'created_at', i.created_at, 'expires_at', i.expires_at
    )
    into v_outgoing
    from public.love_partner_invitations i
    where i.sender_id = v_user and i.status = 'pending'
    order by i.created_at desc limit 1;

  select jsonb_build_object(
      'id', i.id, 'sender_id', i.sender_id, 'status', i.status,
      'created_at', i.created_at, 'expires_at', i.expires_at,
      'sender', jsonb_build_object(
        'id', sender.id, 'username', sender.username,
        'display_name', sender.display_name, 'avatar_url', sender.avatar_url,
        'saki_id', sender.saki_id
      )
    )
    into v_incoming
    from public.love_partner_invitations i
    join public.profiles sender on sender.id = i.sender_id
    where i.recipient_id = v_user and i.status = 'pending'
    order by i.created_at desc limit 1;

  return jsonb_build_object(
    'profile', coalesce(v_profile, '{}'::jsonb),
    'gold_balance', v_balance,
    'relationship', v_relationship,
    'outgoing_invite', v_outgoing,
    'incoming_invite', v_incoming
  );
end;
$$;
revoke all on function public.saki_love_house_state() from public, anon;
grant execute on function public.saki_love_house_state() to authenticated;

create or replace function public.saki_send_love_partner_invite(p_recipient_id uuid)
returns jsonb
language plpgsql
security definer
set search_path = public, pg_temp
as $$
declare
  v_sender uuid := auth.uid();
  v_invite_id uuid;
  v_expires_at timestamptz;
  v_balance bigint;
  v_cost constant bigint := 300000;
begin
  if v_sender is null then
    raise exception 'authentication_required' using errcode = '28000';
  end if;
  if p_recipient_id is null or p_recipient_id = v_sender then
    raise exception 'invalid_love_partner' using errcode = '22023';
  end if;

  perform public.expire_love_partner_invites();
  perform pg_advisory_xact_lock(hashtextextended(least(v_sender::text, p_recipient_id::text), 0));
  perform pg_advisory_xact_lock(hashtextextended(greatest(v_sender::text, p_recipient_id::text), 0));

  if not exists (select 1 from public.profiles where id = p_recipient_id) then
    raise exception 'love_partner_not_found' using errcode = 'P0002';
  end if;
  if not exists (
    select 1 from public.follows a
    join public.follows b on b.follower_id = a.following_id and b.following_id = a.follower_id
    where a.follower_id = v_sender and a.following_id = p_recipient_id
  ) then
    raise exception 'mutual_follow_required' using errcode = '42501';
  end if;
  if exists (
    select 1 from public.love_relationships r
    where r.ended_at is null
      and (r.user_a_id in (v_sender, p_recipient_id) or r.user_b_id in (v_sender, p_recipient_id))
  ) then
    raise exception 'user_already_has_love_partner' using errcode = '23505';
  end if;
  if exists (
    select 1 from public.love_partner_invitations i
    where i.status = 'pending'
      and (i.sender_id in (v_sender, p_recipient_id) or i.recipient_id in (v_sender, p_recipient_id))
  ) then
    raise exception 'pending_love_invitation_exists' using errcode = '23505';
  end if;

  update public.saki_account_modules
    set gold_coins = gold_coins - v_cost, updated_at = now()
    where user_id = v_sender and gold_coins >= v_cost
    returning gold_coins into v_balance;
  if not found then
    raise exception 'insufficient_gold' using errcode = 'P0001';
  end if;

  v_expires_at := now() + interval '7 days';
  insert into public.love_partner_invitations
      (sender_id, recipient_id, status, gold_cost, expires_at)
    values (v_sender, p_recipient_id, 'pending', v_cost, v_expires_at)
    returning id into v_invite_id;

  insert into public.notifications (user_id, actor_id, type, entity_id, data)
    values (p_recipient_id, v_sender, 'love_partner_invite', v_invite_id,
      'تنتهي الدعوة بعد 7 أيام. يُعاد مبلغ 300,000 ذهب تلقائيًا إذا رُفضت أو انتهت المهلة.');

  return jsonb_build_object(
    'status', 'pending', 'invite_id', v_invite_id,
    'expires_at', v_expires_at, 'gold_balance', v_balance,
    'gold_cost', v_cost
  );
end;
$$;
revoke all on function public.saki_send_love_partner_invite(uuid) from public, anon;
grant execute on function public.saki_send_love_partner_invite(uuid) to authenticated;

create or replace function public.saki_respond_love_partner_invite(
  p_invite_id uuid,
  p_accept boolean
)
returns jsonb
language plpgsql
security definer
set search_path = public, pg_temp
as $$
declare
  v_user uuid := auth.uid();
  v_invite public.love_partner_invitations%rowtype;
  v_relationship_id uuid;
  v_balance bigint;
begin
  if v_user is null then
    raise exception 'authentication_required' using errcode = '28000';
  end if;

  perform public.expire_love_partner_invites();
  select * into v_invite
    from public.love_partner_invitations where id = p_invite_id;
  if not found then
    raise exception 'love_invitation_not_found' using errcode = 'P0002';
  end if;
  if v_invite.recipient_id <> v_user then
    raise exception 'not_love_invitation_recipient' using errcode = '42501';
  end if;
  if v_invite.status <> 'pending' then
    return jsonb_build_object('status', v_invite.status);
  end if;

  perform pg_advisory_xact_lock(hashtextextended(least(v_invite.sender_id::text, v_invite.recipient_id::text), 0));
  perform pg_advisory_xact_lock(hashtextextended(greatest(v_invite.sender_id::text, v_invite.recipient_id::text), 0));
  select * into v_invite
    from public.love_partner_invitations where id = p_invite_id for update;
  if v_invite.status <> 'pending' then
    return jsonb_build_object('status', v_invite.status);
  end if;
  if v_invite.expires_at <= now() then
    update public.love_partner_invitations
      set status = 'expired', resolved_at = now()
      where id = v_invite.id and status = 'pending';
    v_balance := public._saki_refund_love_invite_gold(v_invite.sender_id, v_invite.gold_cost);
    update public.notifications
      set is_read = true,
          data = 'انتهت مهلة الدعوة، وتمت إعادة 300,000 ذهب إلى المرسل.'
      where user_id = v_invite.recipient_id and type = 'love_partner_invite' and entity_id = v_invite.id;
    insert into public.notifications (user_id, actor_id, type, entity_id, data)
      values (v_invite.sender_id, v_invite.recipient_id, 'love_partner_expired', v_invite.id,
        'انتهت مهلة دعوة بيت الحب، وتمت إعادة 300,000 ذهب إلى رصيدك.');
    return jsonb_build_object('status', 'expired', 'gold_balance', v_balance);
  end if;

  if p_accept then
    if not exists (
      select 1 from public.follows a
      join public.follows b on b.follower_id = a.following_id and b.following_id = a.follower_id
      where a.follower_id = v_invite.sender_id and a.following_id = v_invite.recipient_id
    ) then
      update public.love_partner_invitations
        set status = 'rejected', resolved_at = now()
        where id = v_invite.id and status = 'pending';
      v_balance := public._saki_refund_love_invite_gold(v_invite.sender_id, v_invite.gold_cost);
      update public.notifications set is_read = true,
          data = 'تعذر إكمال العلاقة لأن المتابعة المتبادلة لم تعد قائمة؛ أُعيد الذهب إلى المرسل.'
        where user_id = v_invite.recipient_id and type = 'love_partner_invite' and entity_id = v_invite.id;
      insert into public.notifications (user_id, actor_id, type, entity_id, data)
        values (v_invite.sender_id, v_invite.recipient_id, 'love_partner_rejected', v_invite.id,
          'تعذر إكمال العلاقة لأن المتابعة المتبادلة لم تعد قائمة؛ أُعيد 300,000 ذهب إلى رصيدك.');
      return jsonb_build_object('status', 'rejected', 'reason', 'mutual_follow_required', 'gold_balance', v_balance);
    end if;

    if exists (
      select 1 from public.love_relationships r
      where r.ended_at is null
        and (r.user_a_id in (v_invite.sender_id, v_invite.recipient_id)
          or r.user_b_id in (v_invite.sender_id, v_invite.recipient_id))
    ) then
      update public.love_partner_invitations
        set status = 'rejected', resolved_at = now()
        where id = v_invite.id and status = 'pending';
      v_balance := public._saki_refund_love_invite_gold(v_invite.sender_id, v_invite.gold_cost);
      update public.notifications set is_read = true,
          data = 'لم تعد العلاقة متاحة؛ أُعيد الذهب إلى المرسل.'
        where user_id = v_invite.recipient_id and type = 'love_partner_invite' and entity_id = v_invite.id;
      insert into public.notifications (user_id, actor_id, type, entity_id, data)
        values (v_invite.sender_id, v_invite.recipient_id, 'love_partner_rejected', v_invite.id,
          'لم تعد العلاقة متاحة؛ أُعيد 300,000 ذهب إلى رصيدك.');
      return jsonb_build_object('status', 'rejected', 'reason', 'partner_unavailable', 'gold_balance', v_balance);
    end if;

    insert into public.love_relationships (user_a_id, user_b_id)
      values (least(v_invite.sender_id, v_invite.recipient_id), greatest(v_invite.sender_id, v_invite.recipient_id))
      returning id into v_relationship_id;
    update public.love_partner_invitations
      set status = 'accepted', resolved_at = now(), relationship_id = v_relationship_id
      where id = v_invite.id and status = 'pending';
    update public.notifications set is_read = true,
        data = 'تم قبول الدعوة؛ أصبحتما شريكين في بيت الحب.'
      where user_id = v_invite.recipient_id and type = 'love_partner_invite' and entity_id = v_invite.id;
    insert into public.notifications (user_id, actor_id, type, entity_id, data)
      values (v_invite.sender_id, v_invite.recipient_id, 'love_partner_accepted', v_relationship_id,
        'تم قبول دعوتك؛ أصبحتما شريكين في بيت الحب.');
    return jsonb_build_object('status', 'accepted', 'relationship_id', v_relationship_id);
  end if;

  update public.love_partner_invitations
    set status = 'rejected', resolved_at = now()
    where id = v_invite.id and status = 'pending';
  v_balance := public._saki_refund_love_invite_gold(v_invite.sender_id, v_invite.gold_cost);
  update public.notifications set is_read = true,
      data = 'تم رفض الدعوة، وأُعيد 300,000 ذهب إلى المرسل.'
    where user_id = v_invite.recipient_id and type = 'love_partner_invite' and entity_id = v_invite.id;
  insert into public.notifications (user_id, actor_id, type, entity_id, data)
    values (v_invite.sender_id, v_invite.recipient_id, 'love_partner_rejected', v_invite.id,
      'تم رفض دعوة بيت الحب، وأُعيد 300,000 ذهب إلى رصيدك.');
  return jsonb_build_object('status', 'rejected', 'gold_balance', v_balance);
end;
$$;
revoke all on function public.saki_respond_love_partner_invite(uuid, boolean) from public, anon;
grant execute on function public.saki_respond_love_partner_invite(uuid, boolean) to authenticated;

create or replace function public.saki_end_love_relationship(p_relationship_id uuid)
returns jsonb
language plpgsql
security definer
set search_path = public, pg_temp
as $$
declare
  v_user uuid := auth.uid();
  v_relationship public.love_relationships%rowtype;
  v_partner uuid;
begin
  if v_user is null then
    raise exception 'authentication_required' using errcode = '28000';
  end if;
  select * into v_relationship
    from public.love_relationships
    where id = p_relationship_id and (user_a_id = v_user or user_b_id = v_user);
  if not found then
    raise exception 'love_relationship_not_found' using errcode = 'P0002';
  end if;
  perform pg_advisory_xact_lock(hashtextextended(least(v_relationship.user_a_id::text, v_relationship.user_b_id::text), 0));
  perform pg_advisory_xact_lock(hashtextextended(greatest(v_relationship.user_a_id::text, v_relationship.user_b_id::text), 0));
  select * into v_relationship
    from public.love_relationships where id = p_relationship_id for update;
  if v_relationship.ended_at is not null then
    return jsonb_build_object('status', 'already_ended');
  end if;
  if v_relationship.user_a_id <> v_user and v_relationship.user_b_id <> v_user then
    raise exception 'not_love_relationship_participant' using errcode = '42501';
  end if;
  v_partner := case when v_relationship.user_a_id = v_user then v_relationship.user_b_id else v_relationship.user_a_id end;
  update public.love_relationships
    set ended_at = now(), ended_by = v_user
    where id = p_relationship_id and ended_at is null;
  insert into public.notifications (user_id, actor_id, type, entity_id, data)
    values (v_partner, v_user, 'love_partner_ended', p_relationship_id,
      'أنهى شريكك علاقة بيت الحب.');
  return jsonb_build_object('status', 'ended');
end;
$$;
revoke all on function public.saki_end_love_relationship(uuid) from public, anon;
grant execute on function public.saki_end_love_relationship(uuid) to authenticated;

-- Expire invitations and refund the sender no later than 15 minutes after expiry.
do $$
declare
  v_job_id bigint;
begin
  for v_job_id in select jobid from cron.job where jobname = 'saki-expire-love-invites' loop
    perform cron.unschedule(v_job_id);
  end loop;
  perform cron.schedule(
    'saki-expire-love-invites',
    '*/15 * * * *',
    'select public.expire_love_partner_invites();'
  );
end;
$$;
