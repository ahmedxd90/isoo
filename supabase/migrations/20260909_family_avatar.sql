alter table public.trace_families add column if not exists avatar_url text;
-- Keep the legacy family-members view compatible with the profile screen.
