drop function if exists public.complete_family_task(uuid,text,bigint);
create function public.complete_family_task(p_family_id uuid,p_task_key text,p_increment bigint default 1)
returns table(result_task_id uuid,result_progress bigint,result_completed boolean,result_family_points bigint)
language plpgsql security definer set search_path=public as $$
declare task_row public.family_tasks%rowtype; member_ok boolean; progress_row public.family_task_progress%rowtype; new_points bigint; step bigint:=greatest(p_increment,1);
begin
  select exists(select 1 from public.family_members fm where fm.family_id=p_family_id and fm.user_id=auth.uid() and fm.status='active') into member_ok;
  if not member_ok then raise exception 'family_member_required'; end if;
  select ft.* into task_row from public.family_tasks ft where ft.family_id=p_family_id and ft.task_key=p_task_key limit 1;
  if task_row.id is null then raise exception 'family_task_not_found'; end if;
  insert into public.family_task_progress(task_id,family_id,user_id,task_date,progress) values(task_row.id,p_family_id,auth.uid(),current_date,0) on conflict(task_id,user_id,task_date) do nothing;
  select ftp.* into progress_row from public.family_task_progress ftp where ftp.task_id=task_row.id and ftp.user_id=auth.uid() and ftp.task_date=current_date for update;
  if progress_row.completed_at is null then
    update public.family_task_progress ftp set progress=least(task_row.daily_target,progress_row.progress+step),completed_at=case when progress_row.progress+step>=task_row.daily_target then now() else null end where ftp.task_id=task_row.id and ftp.user_id=auth.uid() and ftp.task_date=current_date returning ftp.* into progress_row;
    if progress_row.completed_at is not null then update public.families f set points=f.points+task_row.reward_points,level=public.family_level_for_points(f.points+task_row.reward_points),weekly_points=f.weekly_points+task_row.reward_points where f.id=p_family_id returning f.points into new_points; else select f.points into new_points from public.families f where f.id=p_family_id; end if;
  else select f.points into new_points from public.families f where f.id=p_family_id; end if;
  return query select task_row.id,progress_row.progress,(progress_row.completed_at is not null),new_points;
end; $$;
grant execute on function public.complete_family_task(uuid,text,bigint) to authenticated;
