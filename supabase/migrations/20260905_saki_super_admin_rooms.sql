alter table public.rooms add column if not exists is_official boolean not null default false;
create or replace function public.admin_set_room_id(p_room_id uuid,p_new_room_id text,p_official boolean default false)
returns void language plpgsql security definer set search_path=public as $$ begin
 if not public.is_saki_super_admin() or p_new_room_id !~ '^[0-9]{9}$' then raise exception 'admin_required'; end if;
 update rooms set room_id=p_new_room_id,is_official=p_official where id=p_room_id;
end; $$;
revoke all on function public.admin_set_room_id(uuid,text,boolean) from public;
grant execute on function public.admin_set_room_id(uuid,text,boolean) to authenticated;
