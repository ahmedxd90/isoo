alter table public.profiles add column if not exists is_super_admin boolean not null default false;
alter table public.profiles add column if not exists super_admin_label text;
update public.profiles set is_super_admin = true, super_admin_label = 'SUPER ADMIN' where saki_id = 1000;

create table if not exists public.app_bans (
  user_id uuid primary key references public.profiles(id) on delete cascade,
  banned_by uuid not null references public.profiles(id),
  expires_at timestamptz,
  reason text,
  created_at timestamptz not null default now()
);
alter table public.app_bans enable row level security;

alter table public.room_gift_catalog add column if not exists media_url text;
alter table public.room_gift_catalog add column if not exists media_type text not null default 'emoji';

create or replace function public.is_saki_super_admin()
returns boolean language sql stable security definer set search_path=public as $$
  select exists(select 1 from profiles where id=auth.uid() and (is_super_admin=true or saki_id=1000));
$$;
revoke all on function public.is_saki_super_admin() from public;
grant execute on function public.is_saki_super_admin() to authenticated;

drop policy if exists app_bans_self_read on public.app_bans;
create policy app_bans_self_read on public.app_bans for select using (user_id=auth.uid() or public.is_saki_super_admin());
drop policy if exists app_bans_admin_write on public.app_bans;
create policy app_bans_admin_write on public.app_bans for all using (public.is_saki_super_admin()) with check (public.is_saki_super_admin());
drop policy if exists gift_catalog_admin_write on public.room_gift_catalog;
create policy gift_catalog_admin_write on public.room_gift_catalog for all using (public.is_saki_super_admin()) with check (public.is_saki_super_admin());

create or replace function public.admin_ban_app(p_saki_id bigint,p_duration interval,p_reason text default null)
returns void language plpgsql security definer set search_path=public as $$
declare target uuid; begin
 if not public.is_saki_super_admin() then raise exception 'admin_required'; end if;
 select id into target from profiles where saki_id=p_saki_id;
 if target is null then raise exception 'user_not_found'; end if;
 insert into app_bans(user_id,banned_by,expires_at,reason) values(target,auth.uid(),case when p_duration is null then null else now()+p_duration end,p_reason)
 on conflict(user_id) do update set banned_by=excluded.banned_by,expires_at=excluded.expires_at,reason=excluded.reason;
end; $$;
create or replace function public.admin_unban_app(p_user_id uuid)
returns void language plpgsql security definer set search_path=public as $$ begin
 if not public.is_saki_super_admin() then raise exception 'admin_required'; end if; delete from app_bans where user_id=p_user_id; end; $$;
create or replace function public.admin_add_gold(p_saki_id bigint,p_amount bigint)
returns void language plpgsql security definer set search_path=public as $$ declare target uuid; begin
 if not public.is_saki_super_admin() or p_amount<=0 then raise exception 'admin_required'; end if;
 select id into target from profiles where saki_id=p_saki_id; if target is null then raise exception 'user_not_found'; end if;
 insert into saki_account_modules(user_id,gold_coins) values(target,p_amount) on conflict(user_id) do update set gold_coins=saki_account_modules.gold_coins+p_amount,updated_at=now(); end; $$;
create or replace function public.admin_set_vip(p_saki_id bigint,p_level integer,p_days integer)
returns void language plpgsql security definer set search_path=public as $$ declare target uuid; begin
 if not public.is_saki_super_admin() or p_level<0 or p_level>7 or p_days<0 then raise exception 'admin_required'; end if;
 select id into target from profiles where saki_id=p_saki_id; if target is null then raise exception 'user_not_found'; end if;
 update profiles set vip_level=p_level,vip_expires_at=case when p_level=0 then null else now()+(p_days||' days')::interval end,updated_at=now() where id=target;
 update saki_account_modules set vip_level=p_level,vip_label=case when p_level=0 then null else 'VIP '||p_level end,updated_at=now() where user_id=target; end; $$;
create or replace function public.admin_set_saki_id(p_user_id uuid,p_new_id bigint)
returns void language plpgsql security definer set search_path=public as $$ begin
 if not public.is_saki_super_admin() or p_new_id<1 then raise exception 'admin_required'; end if; update profiles set saki_id=p_new_id,updated_at=now() where id=p_user_id; end; $$;
revoke all on function public.admin_ban_app(bigint,interval,text),public.admin_unban_app(uuid),public.admin_add_gold(bigint,bigint),public.admin_set_vip(bigint,integer,integer),public.admin_set_saki_id(uuid,bigint) from public;
grant execute on function public.admin_ban_app(bigint,interval,text),public.admin_unban_app(uuid),public.admin_add_gold(bigint,bigint),public.admin_set_vip(bigint,integer,integer),public.admin_set_saki_id(uuid,bigint) to authenticated;

create or replace function public.admin_set_room_id(p_room_id uuid,p_new_room_id text,p_official boolean default false)
returns void language plpgsql security definer set search_path=public as $$ begin
 if not public.is_saki_super_admin() or p_new_room_id !~ '^[0-9]{9}$' then raise exception 'admin_required'; end if;
 update rooms set room_id=p_new_room_id,is_official=p_official where id=p_room_id;
end; $$;
alter table public.rooms add column if not exists is_official boolean not null default false;
revoke all on function public.admin_set_room_id(uuid,text,boolean) from public;
grant execute on function public.admin_set_room_id(uuid,text,boolean) to authenticated;
