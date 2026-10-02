-- These SECURITY DEFINER dashboards scope all returned rows and balances to
-- auth.uid() (and the owner/agent membership checks inside their functions).
-- They are required by the native profile shortcuts, never by anonymous users.
revoke all on function public.host_agency_dashboard() from public, anon;
revoke all on function public.host_agency_host_dashboard() from public, anon;
revoke all on function public.host_agency_wallet_dashboard() from public, anon;
grant execute on function public.host_agency_dashboard() to authenticated;
grant execute on function public.host_agency_host_dashboard() to authenticated;
grant execute on function public.host_agency_wallet_dashboard() to authenticated;
