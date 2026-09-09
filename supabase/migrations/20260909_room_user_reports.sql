alter table public.user_reports
  add column if not exists room_id uuid references public.rooms(id) on delete set null,
  add column if not exists evidence_url text,
  add column if not exists status text not null default 'new';

alter table public.user_reports drop constraint if exists user_reports_category_check;
alter table public.user_reports add constraint user_reports_category_check
  check (category in ('sexual', 'advertising', 'abuse', 'other', 'promotion', 'harassment'));

alter table public.user_reports
  drop constraint if exists user_reports_status_check;
alter table public.user_reports
  add constraint user_reports_status_check
  check (status in ('new', 'reviewing', 'resolved', 'rejected'));

create index if not exists user_reports_room_idx on public.user_reports(room_id);
create index if not exists user_reports_status_idx on public.user_reports(status);

drop policy if exists user_reports_admin_select on public.user_reports;
drop policy if exists user_reports_admin_update on public.user_reports;
create policy user_reports_admin_select on public.user_reports
  for select to authenticated using (
    auth.uid() = reporter_id or public.is_saki_super_admin()
  );
create policy user_reports_admin_update on public.user_reports
  for update to authenticated using (public.is_saki_super_admin())
  with check (public.is_saki_super_admin());

insert into storage.buckets (id, name, public)
values ('report_evidence', 'report_evidence', true)
on conflict (id) do nothing;

drop policy if exists report_evidence_public_read on storage.objects;
drop policy if exists report_evidence_owner_insert on storage.objects;
create policy report_evidence_public_read on storage.objects
  for select using (bucket_id = 'report_evidence');
create policy report_evidence_owner_insert on storage.objects
  for insert to authenticated with check (
    bucket_id = 'report_evidence' and (storage.foldername(name))[1] = auth.uid()::text
  );
