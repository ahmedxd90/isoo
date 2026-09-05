create table if not exists public.saki_account_modules (
  user_id uuid primary key references public.profiles(id) on delete cascade,
  wallet_balance numeric(14,2) not null default 0,
  wallet_currency text not null default 'USD',
  vip_level integer not null default 0,
  vip_label text not null default 'عضو جديد',
  aristocracy_label text not null default 'غير مشترك',
  store_credit numeric(14,2) not null default 0,
  settings jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

alter table public.saki_account_modules enable row level security;
drop policy if exists saki_account_modules_select on public.saki_account_modules;
create policy saki_account_modules_select on public.saki_account_modules for select using ((select auth.uid()) = user_id);
drop policy if exists saki_account_modules_insert on public.saki_account_modules;
create policy saki_account_modules_insert on public.saki_account_modules for insert with check ((select auth.uid()) = user_id);
drop policy if exists saki_account_modules_update on public.saki_account_modules;
create policy saki_account_modules_update on public.saki_account_modules for update using ((select auth.uid()) = user_id) with check ((select auth.uid()) = user_id);
