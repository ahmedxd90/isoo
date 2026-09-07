-- Automatic family task progress from real gifts, room messages, private messages, posts and reels.
create or replace function public.record_family_task_progress(p_user_id uuid, p_task_key text, p_increment bigint default 1)
returns void language plpgsql security definer set search_path=public as $$
declare m record; t public.family_tasks%rowtype; pr public.family_task_progress%rowtype; step bigint:=greatest(p_increment,1);
begin
  for m in select family_id from public.family_members where user_id=p_user_id and status='active' loop
    select * into t from public.family_tasks where family_id=m.family_id and task_key=p_task_key limit 1;
    if t.id is null then continue; end if;
    insert into public.family_task_progress(task_id,family_id,user_id,task_date,progress) values(t.id,m.family_id,p_user_id,current_date,0) on conflict(task_id,user_id,task_date) do nothing;
    select * into pr from public.family_task_progress where task_id=t.id and user_id=p_user_id and task_date=current_date for update;
    if pr.completed_at is null then
      update public.family_task_progress set progress=least(t.daily_target,pr.progress+step),completed_at=case when pr.progress+step>=t.daily_target then now() end where task_id=t.id and user_id=p_user_id and task_date=current_date;
      if pr.progress+step>=t.daily_target then update public.families set points=points+t.reward_points,level=public.family_level_for_points(points+t.reward_points),weekly_points=weekly_points+t.reward_points where id=m.family_id; end if;
    end if;
  end loop;
end; $$;

create or replace function public.family_room_message_task() returns trigger language plpgsql security definer set search_path=public as $$ begin perform public.record_family_task_progress(new.sender_id,'room_messages_5',1); return new; end; $$;
create or replace function public.family_private_message_task() returns trigger language plpgsql security definer set search_path=public as $$ begin perform public.record_family_task_progress(new.sender_id,'private_5',1); return new; end; $$;
create or replace function public.family_post_task() returns trigger language plpgsql security definer set search_path=public as $$ begin perform public.record_family_task_progress(new.author_id,'post',1); return new; end; $$;
create or replace function public.family_reel_task() returns trigger language plpgsql security definer set search_path=public as $$ begin perform public.record_family_task_progress(new.author_id,'reel',1); return new; end; $$;
create or replace function public.family_gift_task() returns trigger language plpgsql security definer set search_path=public as $$ begin perform public.record_family_task_progress(new.sender_id,'gift_10000',new.total_price); perform public.record_family_task_progress(new.sender_id,'gift_100000',new.total_price); return new; end; $$;

drop trigger if exists family_room_message_task_trigger on public.room_messages;
create trigger family_room_message_task_trigger after insert on public.room_messages for each row execute function public.family_room_message_task();
drop trigger if exists family_private_message_task_trigger on public.messages;
create trigger family_private_message_task_trigger after insert on public.messages for each row execute function public.family_private_message_task();
drop trigger if exists family_post_task_trigger on public.posts;
create trigger family_post_task_trigger after insert on public.posts for each row execute function public.family_post_task();
drop trigger if exists family_reel_task_trigger on public.reels;
create trigger family_reel_task_trigger after insert on public.reels for each row execute function public.family_reel_task();
drop trigger if exists family_gift_task_trigger on public.room_gifts;
create trigger family_gift_task_trigger after insert on public.room_gifts for each row execute function public.family_gift_task();
