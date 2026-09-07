create sequence if not exists public.family_h_id_seq minvalue 784653 start 784653 increment 1;

create table if not exists public.families (
  id uuid primary key default gen_random_uuid(),
  h_id bigint not null unique default nextval('public.family_h_id_seq'),
  owner_id uuid not null references public.profiles(id) on delete restrict,
  name text not null check (char_length(trim(name)) between 2 and 40),
  family_alias text not null unique check (char_length(trim(family_alias)) >= 5 and family_alias ~ '^[[:alnum:]_\u0600-\u06FF]+$'),
  description text not null default '',
  avatar_url text,
  level integer not null default 1 check (level >= 1),
  points bigint not null default 0 check (points >= 0),
  stars bigint not null default 0 check (stars >= 0),
  created_at timestamptz not null default now()
);

create table if not exists public.family_members (
  family_id uuid not null references public.families(id) on delete cascade,
  user_id uuid not null references public.profiles(id) on delete cascade,
  role text not null default 'member' check (role in ('owner','member')),
  status text not null default 'active' check (status in ('active','left')),
  joined_at timestamptz not null default now(),
  primary key (family_id,user_id)
);

create table if not exists public.family_join_requests (
  id uuid primary key default gen_random_uuid(),
  family_id uuid not null references public.families(id) on delete cascade,
  user_id uuid not null references public.profiles(id) on delete cascade,
  status text not null default 'pending' check (status in ('pending','approved','rejected')),
  created_at timestamptz not null default now(),
  unique(family_id,user_id)
);

create table if not exists public.family_tasks (
  id uuid primary key default gen_random_uuid(),
  family_id uuid not null references public.families(id) on delete cascade,
  title text not null,
  target bigint not null default 1,
  progress bigint not null default 0,
  reward_points bigint not null default 0,
  period text not null default 'daily',
  created_at timestamptz not null default now()
);

alter table public.families enable row level security;
alter table public.family_members enable row level security;
alter table public.family_join_requests enable row level security;
alter table public.family_tasks enable row level security;

drop policy if exists families_read on public.families;
create policy families_read on public.families for select to authenticated using (true);
drop policy if exists family_members_read on public.family_members;
create policy family_members_read on public.family_members for select to authenticated using (true);
drop policy if exists family_requests_read on public.family_join_requests;
create policy family_requests_read on public.family_join_requests for select to authenticated using (user_id = auth.uid() or exists (select 1 from public.families f where f.id = family_id and f.owner_id = auth.uid()));
drop policy if exists family_tasks_read on public.family_tasks;
create policy family_tasks_read on public.family_tasks for select to authenticated using (true);

create or replace function public.create_family(
  p_name text,
  p_alias text,
  p_description text,
  p_avatar_url text default null
) returns public.families
language plpgsql security definer set search_path = public
as $$
declare result public.families;
begin
  if exists (select 1 from family_members where user_id = auth.uid() and status = 'active') then raise exception 'already_in_family'; end if;
  if char_length(trim(p_alias)) < 5 or trim(p_alias) !~ '^[[:alnum:]_\u0600-\u06FF]+$' then raise exception 'invalid_family_alias'; end if;
  update saki_account_modules set gold_coins = gold_coins - 500000, updated_at = now() where user_id = auth.uid() and gold_coins >= 500000;
  if not found then raise exception 'insufficient_gold'; end if;
  insert into families(owner_id,name,family_alias,description,avatar_url) values(auth.uid(),trim(p_name),trim(p_alias),trim(coalesce(p_description,'')),nullif(trim(p_avatar_url),'')) returning * into result;
  insert into family_members(family_id,user_id,role) values(result.id,auth.uid(),'owner');
  insert into family_tasks(family_id,title,target,reward_points) values
    (result.id,'إرسال هدايا في الغرف',100,1000),
    (result.id,'استقبال هدايا في الغرف',100,1000),
    (result.id,'نشاط أعضاء العائلة',10,500);
  return result;
exception when unique_violation then raise exception 'family_alias_taken';
end;
$$;

grant execute on function public.create_family(text,text,text,text) to authenticated;

create or replace function public.request_family_join(p_family_id uuid)
returns void language plpgsql security definer set search_path = public
as $$
begin
  if exists (select 1 from family_members where user_id=auth.uid() and status='active') then raise exception 'already_in_family'; end if;
  insert into family_join_requests(family_id,user_id) values(p_family_id,auth.uid())
  on conflict(family_id,user_id) do update set status='pending',created_at=now();
end;
$$;
grant execute on function public.request_family_join(uuid) to authenticated;

create or replace function public.family_level_for_points(p_points bigint)
returns integer language sql immutable as $$ select greatest(1, least(100, floor(sqrt(greatest(p_points,0)::numeric / 1000))::int + 1)); $$;

create or replace view public.family_square as
select f.*, count(fm.user_id)::int as member_count,
       p.username as owner_username, p.avatar_url as owner_avatar_url,
       r.id as owner_room_id, r.room_id as owner_room_number, r.name as owner_room_name
from public.families f
left join public.family_members fm on fm.family_id=f.id and fm.status='active'
left join public.profiles p on p.id=f.owner_id
left join public.rooms r on r.owner_id=f.owner_id and r.is_active=true
group by f.id,p.username,p.avatar_url,r.id,r.room_id,r.name;
