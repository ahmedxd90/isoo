-- Legacy host-agency payout requests from the repository schema.
-- Applied after the source migrations create trace_agencies and profiles.
create table if not exists public.host_agency_payout_requests (
  id uuid primary key default gen_random_uuid(),
  agency_id uuid not null references public.trace_agencies(id) on delete restrict,
  host_id uuid not null references public.profiles(id) on delete restrict,
  diamonds bigint not null default 0,
  usd_amount numeric(20,6) not null default 0,
  status text not null,
  created_at timestamptz not null default now(),
  reviewed_at timestamptz
);

create index if not exists host_agency_payout_requests_agency_id_idx
  on public.host_agency_payout_requests (agency_id);
create index if not exists host_agency_payout_requests_host_id_idx
  on public.host_agency_payout_requests (host_id);

alter table public.host_agency_payout_requests enable row level security;
