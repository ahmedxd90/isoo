create or replace function public.saki_notify_post_like()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare target_user uuid;
begin
  select author_id into target_user from public.posts where id = new.post_id;
  if target_user is not null and target_user <> new.user_id then
    insert into public.notifications(user_id, actor_id, type, entity_id, is_read)
    values (target_user, new.user_id, 'like', new.post_id, false);
  end if;
  return new;
end;
$$;

drop trigger if exists saki_post_like_notification on public.post_likes;
create trigger saki_post_like_notification after insert on public.post_likes
for each row execute function public.saki_notify_post_like();

create or replace function public.saki_notify_post_comment()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare target_user uuid;
begin
  select author_id into target_user from public.posts where id = new.post_id;
  if target_user is not null and target_user <> new.user_id then
    insert into public.notifications(user_id, actor_id, type, entity_id, is_read)
    values (target_user, new.user_id, 'comment', new.post_id, false);
  end if;
  return new;
end;
$$;

drop trigger if exists saki_post_comment_notification on public.post_comments;
create trigger saki_post_comment_notification after insert on public.post_comments
for each row execute function public.saki_notify_post_comment();

create or replace function public.saki_notify_reel_like()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare target_user uuid;
begin
  select author_id into target_user from public.reels where id = new.reel_id;
  if target_user is not null and target_user <> new.user_id then
    insert into public.notifications(user_id, actor_id, type, entity_id, is_read)
    values (target_user, new.user_id, 'like', new.reel_id, false);
  end if;
  return new;
end;
$$;

drop trigger if exists saki_reel_like_notification on public.reel_likes;
create trigger saki_reel_like_notification after insert on public.reel_likes
for each row execute function public.saki_notify_reel_like();

create or replace function public.saki_notify_reel_comment()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare target_user uuid;
begin
  select author_id into target_user from public.reels where id = new.reel_id;
  if target_user is not null and target_user <> new.user_id then
    insert into public.notifications(user_id, actor_id, type, entity_id, is_read)
    values (target_user, new.user_id, 'comment', new.reel_id, false);
  end if;
  return new;
end;
$$;

drop trigger if exists saki_reel_comment_notification on public.reel_comments;
create trigger saki_reel_comment_notification after insert on public.reel_comments
for each row execute function public.saki_notify_reel_comment();

create or replace function public.saki_notify_follow()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  if new.following_id <> new.follower_id then
    insert into public.notifications(user_id, actor_id, type, entity_id, is_read)
    values (new.following_id, new.follower_id, 'follow', new.follower_id, false);
  end if;
  return new;
end;
$$;

drop trigger if exists saki_follow_notification on public.follows;
create trigger saki_follow_notification after insert on public.follows
for each row execute function public.saki_notify_follow();

create or replace function public.saki_notify_message()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare target_user uuid;
begin
  for target_user in select user_id from public.conversation_members where conversation_id = new.conversation_id and user_id <> new.sender_id loop
    insert into public.notifications(user_id, actor_id, type, entity_id, is_read)
    values (target_user, new.sender_id, 'message', new.conversation_id, false);
  end loop;
  return new;
end;
$$;

drop trigger if exists saki_message_notification on public.messages;
create trigger saki_message_notification after insert on public.messages
for each row execute function public.saki_notify_message();

revoke execute on function public.saki_notify_post_like() from public, anon, authenticated;
revoke execute on function public.saki_notify_post_comment() from public, anon, authenticated;
revoke execute on function public.saki_notify_reel_like() from public, anon, authenticated;
revoke execute on function public.saki_notify_reel_comment() from public, anon, authenticated;
revoke execute on function public.saki_notify_follow() from public, anon, authenticated;
revoke execute on function public.saki_notify_message() from public, anon, authenticated;
