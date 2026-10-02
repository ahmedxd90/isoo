-- Older admin builds may omit display_name while still sending name.
-- Normalize the insert before NOT NULL checks without weakening catalog constraints.
create or replace function private.saki_normalize_room_gift_catalog_insert()
returns trigger
language plpgsql
set search_path = pg_catalog, public, pg_temp
as $$
declare
  resolved_name text;
begin
  resolved_name := coalesce(
    nullif(btrim(new.display_name), ''),
    nullif(btrim(new.name), '')
  );

  if resolved_name is not null then
    new.display_name := resolved_name;
    new.name := coalesce(nullif(btrim(new.name), ''), resolved_name);
  end if;

  if new.emoji is null or btrim(new.emoji) = '' then
    new.emoji := '🎁';
  end if;

  if new.icon is null or btrim(new.icon) = '' then
    new.icon := coalesce(nullif(btrim(new.asset_url), ''), new.emoji);
  end if;

  if new.asset_url is null or btrim(new.asset_url) = '' then
    new.asset_url := new.icon;
  end if;

  return new;
end;
$$;

revoke all on function private.saki_normalize_room_gift_catalog_insert()
  from public, anon, authenticated;

drop trigger if exists saki_room_gift_catalog_insert_defaults
  on public.room_gift_catalog;
create trigger saki_room_gift_catalog_insert_defaults
  before insert on public.room_gift_catalog
  for each row execute function private.saki_normalize_room_gift_catalog_insert();
