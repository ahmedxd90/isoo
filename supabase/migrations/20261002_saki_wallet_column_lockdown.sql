-- Wallet balances must only be changed by trusted SECURITY DEFINER RPCs.
-- The Flutter client reads its own row, creates it with only user_id, and
-- updates only user-owned settings and updated_at.

revoke all privileges on table public.saki_account_modules
  from public, anon, authenticated;

-- Remove any previous column-level insert/update grants as well as table-level
-- grants, so a stale column grant cannot preserve a direct balance write path.
revoke insert (user_id, wallet_balance, wallet_currency, vip_level, vip_label,
  aristocracy_label, store_credit, settings, created_at, updated_at,
  gold_coins, diamonds, wealth_xp, wealth_level, charm_xp, charm_level)
  on table public.saki_account_modules from public, anon, authenticated;
revoke update (user_id, wallet_balance, wallet_currency, vip_level, vip_label,
  aristocracy_label, store_credit, settings, created_at, updated_at,
  gold_coins, diamonds, wealth_xp, wealth_level, charm_xp, charm_level)
  on table public.saki_account_modules from public, anon, authenticated;

-- Preserve only the client operations used by the app. RLS continues to scope
-- reads/inserts/updates to the authenticated user's own account row.
grant select on table public.saki_account_modules to authenticated;
grant insert (user_id) on table public.saki_account_modules to authenticated;
grant update (settings, updated_at) on table public.saki_account_modules to authenticated;
grant all privileges on table public.saki_account_modules to service_role;
