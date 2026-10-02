-- Rebuild only the application's public schema on the approved faxt target.
-- Preserve these read-only system catalogs and all of Supabase Auth/Storage:
-- room_gift_catalog (including its 12 entries), wallet_topup_packages,
-- aristocracy_levels, aristocracy_features. User data in these old tables was
-- verified empty before this reset. Storage buckets/settings are not modified.

do $$
declare r record;
begin
  -- Remove the old automatic-RLS DDL event trigger before rebuilding tables.
  for r in
    select e.evtname
    from pg_event_trigger e
    join pg_proc p on p.oid=e.evtfoid
    join pg_namespace n on n.oid=p.pronamespace
    where n.nspname='public'
  loop
    execute format('drop event trigger if exists %I', r.evtname);
  end loop;

  -- Remove every application table except the static catalogs explicitly retained.
  for r in
    select schemaname, tablename
    from pg_tables
    where schemaname='public'
      and tablename not in (
        'room_gift_catalog',
        'wallet_topup_packages',
        'aristocracy_levels',
        'aristocracy_features'
      )
  loop
    execute format('drop table if exists %I.%I cascade', r.schemaname, r.tablename);
  end loop;

  -- Remove old public views and materialized views as part of the same app-schema reset.
  for r in select schemaname, viewname from pg_views where schemaname='public'
  loop
    execute format('drop view if exists %I.%I cascade', r.schemaname, r.viewname);
  end loop;
  for r in select schemaname, matviewname from pg_matviews where schemaname='public'
  loop
    execute format('drop materialized view if exists %I.%I cascade', r.schemaname, r.matviewname);
  end loop;

  -- Old user triggers on auth.users depend on public functions and are removed
  -- through CASCADE; the isoo foundation migration installs the new profile trigger.
  for r in
    select p.oid::regprocedure as signature, p.prokind
    from pg_proc p
    join pg_namespace n on n.oid=p.pronamespace
    where n.nspname='public' and p.prokind in ('f','p')
      and not exists (
        select 1 from pg_depend d
        where d.classid='pg_proc'::regclass and d.objid=p.oid
          and d.refclassid='pg_extension'::regclass and d.deptype='e'
      )
  loop
    if r.prokind='p' then
      execute format('drop procedure if exists %s cascade', r.signature);
    else
      execute format('drop function if exists %s cascade', r.signature);
    end if;
  end loop;

  -- Drop orphaned sequences, retaining any sequence owned by one of the four
  -- preserved catalogs (normally none of these catalogs use sequences).
  for r in
    select n.nspname, c.relname
    from pg_class c
    join pg_namespace n on n.oid=c.relnamespace
    where n.nspname='public' and c.relkind='S'
      and not exists (
        select 1
        from pg_depend d
        join pg_class t on t.oid=d.refobjid
        where d.classid='pg_class'::regclass and d.objid=c.oid
          and d.refclassid='pg_class'::regclass and d.deptype in ('a','i')
          and t.relname in ('room_gift_catalog','wallet_topup_packages','aristocracy_levels','aristocracy_features')
      )
  loop
    execute format('drop sequence if exists %I.%I cascade', r.nspname, r.relname);
  end loop;
end
$$;
