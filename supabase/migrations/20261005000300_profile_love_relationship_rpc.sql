-- Allow authenticated users to render the active Love House partner
-- on either participant's public profile without exposing invitations.
create or replace function public.saki_profile_love_relationship(p_user_id uuid)
returns jsonb
language plpgsql
security definer
set search_path = public, pg_temp
as $$
declare
  v_relationship jsonb;
begin
  if auth.uid() is null then
    raise exception 'authentication_required' using errcode = '28000';
  end if;

  select jsonb_build_object(
      'id', r.id,
      'started_at', r.started_at,
      'partner', jsonb_build_object(
        'id', partner.id,
        'username', partner.username,
        'display_name', partner.display_name,
        'avatar_url', partner.avatar_url,
        'saki_id', partner.saki_id
      )
    )
    into v_relationship
    from public.love_relationships r
    join public.profiles partner
      on partner.id = case
        when r.user_a_id = p_user_id then r.user_b_id
        else r.user_a_id
      end
    where r.ended_at is null
      and (r.user_a_id = p_user_id or r.user_b_id = p_user_id)
    order by r.started_at desc
    limit 1;

  return jsonb_build_object(
    'relationship', coalesce(v_relationship, '{}'::jsonb)
  );
end;
$$;

revoke all on function public.saki_profile_love_relationship(uuid) from public, anon;
grant execute on function public.saki_profile_love_relationship(uuid) to authenticated;
