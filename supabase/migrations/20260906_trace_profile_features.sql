create table if not exists public.trace_store_catalog (
  id uuid primary key default gen_random_uuid(),
  category text not null check (category in ('avatar_frame','party_theme','entrance_effect')),
  name text not null,
  asset_key text not null,
  price_gold_coins bigint not null default 0 check (price_gold_coins >= 0),
  duration_days integer check (duration_days is null or duration_days > 0),
  is_active boolean not null default true,
  sort_order integer not null default 0,
  created_at timestamptz not null default now()
);

create table if not exists public.trace_store_inventory (
  user_id uuid not null references public.profiles(id) on delete cascade,
  item_id uuid not null references public.trace_store_catalog(id) on delete cascade,
  purchased_at timestamptz not null default now(),
  expires_at timestamptz,
  is_active boolean not null default false,
  primary key (user_id, item_id)
);

create table if not exists public.trace_agencies (
  id uuid primary key default gen_random_uuid(),
  owner_id uuid not null references public.profiles(id) on delete cascade,
  name text not null,
  agent_code text not null unique,
  status text not null default 'active' check (status in ('active','suspended','closed')),
  created_at timestamptz not null default now()
);

create table if not exists public.trace_agency_members (
  agency_id uuid not null references public.trace_agencies(id) on delete cascade,
  user_id uuid not null references public.profiles(id) on delete cascade,
  role text not null default 'member' check (role in ('owner','agent','member')),
  status text not null default 'active' check (status in ('pending','active','rejected','left')),
  joined_at timestamptz not null default now(),
  primary key (agency_id, user_id)
);

create table if not exists public.trace_agency_join_requests (
  id uuid primary key default gen_random_uuid(),
  agency_id uuid not null references public.trace_agencies(id) on delete cascade,
  user_id uuid not null references public.profiles(id) on delete cascade,
  status text not null default 'pending' check (status in ('pending','approved','rejected','cancelled')),
  created_at timestamptz not null default now(),
  reviewed_at timestamptz,
  unique (agency_id, user_id, status)
);

create table if not exists public.trace_families (
  id uuid primary key default gen_random_uuid(),
  owner_id uuid not null references public.profiles(id) on delete cascade,
  name text not null,
  invite_code text not null unique,
  status text not null default 'active' check (status in ('active','suspended','closed')),
  created_at timestamptz not null default now()
);

create table if not exists public.trace_family_members (
  family_id uuid not null references public.trace_families(id) on delete cascade,
  user_id uuid not null references public.profiles(id) on delete cascade,
  role text not null default 'member' check (role in ('owner','admin','member')),
  status text not null default 'active' check (status in ('pending','active','rejected','left')),
  joined_at timestamptz not null default now(),
  primary key (family_id, user_id)
);

create table if not exists public.trace_user_levels (
  user_id uuid primary key references public.profiles(id) on delete cascade,
  experience_points bigint not null default 0 check (experience_points >= 0),
  level integer not null default 1 check (level >= 1),
  updated_at timestamptz not null default now()
);

create table if not exists public.trace_level_rewards (
  id uuid primary key default gen_random_uuid(),
  level integer not null unique check (level >= 1),
  title text not null,
  description text not null,
  reward_type text not null,
  reward_value text not null,
  created_at timestamptz not null default now()
);

create index if not exists trace_store_catalog_active_idx on public.trace_store_catalog(category, is_active, sort_order);
create index if not exists trace_agency_requests_user_idx on public.trace_agency_join_requests(user_id, status);
create index if not exists trace_family_members_user_idx on public.trace_family_members(user_id, status);

alter table public.trace_store_catalog enable row level security;
alter table public.trace_store_inventory enable row level security;
alter table public.trace_agencies enable row level security;
alter table public.trace_agency_members enable row level security;
alter table public.trace_agency_join_requests enable row level security;
alter table public.trace_families enable row level security;
alter table public.trace_family_members enable row level security;
alter table public.trace_user_levels enable row level security;
alter table public.trace_level_rewards enable row level security;

drop policy if exists trace_store_catalog_read on public.trace_store_catalog;
create policy trace_store_catalog_read on public.trace_store_catalog for select to authenticated using (is_active = true);
drop policy if exists trace_store_inventory_self on public.trace_store_inventory;
create policy trace_store_inventory_self on public.trace_store_inventory for select to authenticated using (user_id = auth.uid());
drop policy if exists trace_agencies_read on public.trace_agencies;
create policy trace_agencies_read on public.trace_agencies for select to authenticated using (status = 'active' or owner_id = auth.uid());
drop policy if exists trace_agency_members_self on public.trace_agency_members;
create policy trace_agency_members_self on public.trace_agency_members for select to authenticated using (user_id = auth.uid() or exists (select 1 from public.trace_agencies a where a.id = agency_id and a.owner_id = auth.uid()));
drop policy if exists trace_agency_requests_self on public.trace_agency_join_requests;
create policy trace_agency_requests_self on public.trace_agency_join_requests for select to authenticated using (user_id = auth.uid() or exists (select 1 from public.trace_agencies a where a.id = agency_id and a.owner_id = auth.uid()));
drop policy if exists trace_families_read on public.trace_families;
create policy trace_families_read on public.trace_families for select to authenticated using (status = 'active' or owner_id = auth.uid());
drop policy if exists trace_family_members_self on public.trace_family_members;
create policy trace_family_members_self on public.trace_family_members for select to authenticated using (user_id = auth.uid() or exists (select 1 from public.trace_families f where f.id = family_id and f.owner_id = auth.uid()));
drop policy if exists trace_user_levels_self on public.trace_user_levels;
create policy trace_user_levels_self on public.trace_user_levels for select to authenticated using (user_id = auth.uid());
drop policy if exists trace_level_rewards_read on public.trace_level_rewards;
create policy trace_level_rewards_read on public.trace_level_rewards for select to authenticated using (true);

create or replace function public.purchase_trace_store_item(p_item_id uuid)
returns table(item_id uuid, gold_coins bigint, expires_at timestamptz)
language plpgsql security definer set search_path = public
as $$
declare item public.trace_store_catalog%rowtype; balance bigint; expiry timestamptz;
begin
  if auth.uid() is null then raise exception 'not_authenticated'; end if;
  select * into item from public.trace_store_catalog where id = p_item_id and is_active = true;
  if item.id is null then raise exception 'store_item_not_found'; end if;
  select gold_coins into balance from public.saki_account_modules where user_id = auth.uid() for update;
  if coalesce(balance, 0) < item.price_gold_coins then raise exception 'insufficient_gold_coins'; end if;
  expiry := case when item.duration_days is null then null else now() + make_interval(days => item.duration_days) end;
  update public.saki_account_modules set gold_coins = gold_coins - item.price_gold_coins, updated_at = now() where user_id = auth.uid();
  insert into public.trace_store_inventory(user_id, item_id, expires_at, is_active) values (auth.uid(), item.id, expiry, true)
    on conflict (user_id, item_id) do update set purchased_at = now(), expires_at = excluded.expires_at, is_active = true;
  return query select item.id, (select gold_coins from public.saki_account_modules where user_id = auth.uid()), expiry;
end; $$;

create or replace function public.join_trace_agency(p_agent_code text)
returns public.trace_agency_join_requests
language plpgsql security definer set search_path = public
as $$
declare agency public.trace_agencies%rowtype; request public.trace_agency_join_requests%rowtype;
begin
  if auth.uid() is null then raise exception 'not_authenticated'; end if;
  select * into agency from public.trace_agencies where agent_code = trim(p_agent_code) and status = 'active';
  if agency.id is null then raise exception 'agency_not_found'; end if;
  insert into public.trace_agency_join_requests(agency_id, user_id) values (agency.id, auth.uid())
    on conflict (agency_id, user_id, status) do update set created_at = now()
    returning * into request;
  return request;
end; $$;

create or replace function public.join_trace_family(p_invite_code text)
returns public.trace_family_members
language plpgsql security definer set search_path = public
as $$
declare family public.trace_families%rowtype; membership public.trace_family_members%rowtype;
begin
  if auth.uid() is null then raise exception 'not_authenticated'; end if;
  select * into family from public.trace_families where invite_code = trim(p_invite_code) and status = 'active';
  if family.id is null then raise exception 'family_not_found'; end if;
  insert into public.trace_family_members(family_id, user_id, status) values (family.id, auth.uid(), 'active')
    on conflict (family_id, user_id) do update set status = 'active', joined_at = now()
    returning * into membership;
  return membership;
end; $$;

revoke all on function public.purchase_trace_store_item(uuid) from public;
grant execute on function public.purchase_trace_store_item(uuid) to authenticated;
revoke all on function public.join_trace_agency(text) from public;
grant execute on function public.join_trace_agency(text) to authenticated;
revoke all on function public.join_trace_family(text) from public;
grant execute on function public.join_trace_family(text) to authenticated;

insert into public.trace_level_rewards(level, title, description, reward_type, reward_value) values
(1, 'عضو جديد', 'ابدأ رحلتك في SAKI', 'badge', 'new'),
(2, 'مشارك', 'تفاعل مع الغرف واللحظات', 'frame', 'level_2'),
(3, 'نجم SAKI', 'احصل على شارة نجم', 'badge', 'star'),
(5, 'مميز', 'افتح إطارًا خاصًا', 'frame', 'level_5'),
(10, 'أسطورة', 'افتح مزايا المستوى الأعلى', 'vip', 'level_10')
on conflict (level) do update set title = excluded.title, description = excluded.description, reward_type = excluded.reward_type, reward_value = excluded.reward_value;

insert into public.trace_store_catalog(category, name, asset_key, price_gold_coins, duration_days, sort_order) values
('avatar_frame', 'إطار Trace الأزرق', 'bg_avatar_frame_selected.png', 100, 30, 1),
('avatar_frame', 'إطار Trace البنفسجي', 'bg_avatar_frame_selected.png', 250, 30, 2),
('party_theme', 'ثيم Trace الليلي', 'bg_party_them_selected.png', 300, 30, 1),
('party_theme', 'ثيم Trace الملكي', 'bg_party_them_selected.png', 500, 30, 2),
('entrance_effect', 'تأثير الدخول النجمي', 'bg_entrance_effect_selected.png', 150, 30, 1),
('entrance_effect', 'تأثير الدخول الماسي', 'bg_entrance_effect_selected.png', 350, 30, 2)
on conflict do nothing;

create or replace function public.set_trace_level_from_exp()
returns trigger language plpgsql security definer set search_path = public as $$
begin new.level := greatest(1, floor(new.experience_points / 1000)::integer + 1); new.updated_at := now(); return new; end; $$;
drop trigger if exists trace_level_calculate on public.trace_user_levels;
create trigger trace_level_calculate before insert or update of experience_points on public.trace_user_levels for each row execute function public.set_trace_level_from_exp();
