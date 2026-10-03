-- Match the file types offered by AdminStorePage.
-- PNG is the default store media type, alongside animated/video formats.
alter table public.saki_store_products
  drop constraint if exists saki_store_products_media_type_check;

alter table public.saki_store_products
  add constraint saki_store_products_media_type_check
  check (media_type in ('png', 'mp4', 'svga', 'gif'));
