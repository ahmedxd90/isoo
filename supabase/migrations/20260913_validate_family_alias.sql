create or replace function public.create_family(
  p_name text,
  p_alias text,
  p_description text,
  p_avatar_url text default null
) returns public.families
language plpgsql
security definer
set search_path = public
as $$
declare
  result public.families;
  normalized_alias text := trim(coalesce(p_alias, ''));
begin
  if exists (
    select 1 from public.family_members
    where user_id = auth.uid() and status = 'active'
  ) then
    raise exception 'already_in_family';
  end if;

  if char_length(normalized_alias) < 5
     or normalized_alias !~ '^[A-Za-z0-9_\u0600-\u06FF]+$' then
    raise exception 'invalid_family_alias';
  end if;

  update public.saki_account_modules
  set gold_coins = gold_coins - 500000, updated_at = now()
  where user_id = auth.uid() and gold_coins >= 500000;
  if not found then
    raise exception 'insufficient_gold';
  end if;

  insert into public.families(owner_id, name, family_alias, description, avatar_url)
  values (
    auth.uid(), trim(coalesce(p_name, '')), normalized_alias,
    trim(coalesce(p_description, '')), nullif(trim(coalesce(p_avatar_url, '')), '')
  )
  returning * into result;

  insert into public.family_members(family_id, user_id, role)
  values (result.id, auth.uid(), 'owner');

  insert into public.family_tasks(
    family_id, task_key, title, target, daily_target, reward_points, period
  ) values
    (result.id, 'gift_10000', 'إرسال هدية بقيمة 10,000 ذهبية', 10000, 10000, 2000, 'daily'),
    (result.id, 'private_5', 'إرسال 5 رسائل خاصة لأصدقاء العائلة', 5, 5, 3000, 'daily'),
    (result.id, 'room_messages_5', 'إرسال 5 رسائل في غرفة العائلة', 5, 5, 1000, 'daily'),
    (result.id, 'gift_100000', 'إرسال هدية بقيمة 100,000 ذهبية', 100000, 100000, 10000, 'daily'),
    (result.id, 'post', 'نشر منشور في اللحظات', 1, 1, 1000, 'daily'),
    (result.id, 'reel', 'نشر ريلز', 1, 1, 1000, 'daily');

  return result;
exception
  when unique_violation then
    raise exception 'family_alias_taken';
end;
$$;

grant execute on function public.create_family(text, text, text, text) to authenticated;

drop function if exists public.update_family_settings(uuid, text, text, text, text);
create function public.update_family_settings(
  p_family_id uuid,
  p_name text,
  p_alias text,
  p_avatar_url text,
  p_announcement text
) returns public.families
language plpgsql
security definer
set search_path = public
as $$
declare
  result public.families;
  normalized_alias text := trim(coalesce(p_alias, ''));
begin
  if char_length(normalized_alias) < 5
     or normalized_alias !~ '^[A-Za-z0-9_\u0600-\u06FF]+$' then
    raise exception 'invalid_family_alias';
  end if;

  update public.families
  set name = trim(coalesce(p_name, '')),
      family_alias = normalized_alias,
      avatar_url = nullif(trim(coalesce(p_avatar_url, '')), ''),
      announcement = coalesce(p_announcement, ''),
      updated_at = now()
  where id = p_family_id and owner_id = auth.uid()
  returning * into result;

  if result.id is null then
    raise exception 'family_owner_required';
  end if;
  return result;
exception
  when unique_violation then
    raise exception 'family_alias_taken';
end;
$$;

grant execute on function public.update_family_settings(uuid, text, text, text, text) to authenticated;
