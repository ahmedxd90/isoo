create or replace function public.record_family_task_progress(p_user_id uuid,p_task_key text,p_increment bigint default 1)
returns void language plpgsql security definer set search_path=public as $$
declare m record; t public.family_tasks%rowtype; pr public.family_task_progress%rowtype; step bigint:=greatest(p_increment,1);
begin
  for m in select fm.family_id from public.family_members fm where fm.user_id=p_user_id and fm.status='active' loop
    select ft.* into t from public.family_tasks ft where ft.family_id=m.family_id and ft.task_key=p_task_key limit 1;
    if t.id is null then continue; end if;
    insert into public.family_task_progress(task_id,family_id,user_id,task_date,progress) values(t.id,m.family_id,p_user_id,current_date,0) on conflict(task_id,user_id,task_date) do nothing;
    select ftp.* into pr from public.family_task_progress ftp where ftp.task_id=t.id and ftp.user_id=p_user_id and ftp.task_date=current_date for update;
    if pr.completed_at is null then
      update public.family_task_progress ftp set progress=least(t.daily_target,pr.progress+step),completed_at=case when pr.progress+step>=t.daily_target then now() end where ftp.task_id=t.id and ftp.user_id=p_user_id and ftp.task_date=current_date;
      if pr.progress+step>=t.daily_target then update public.families f set points=f.points+t.reward_points,level=public.family_level_for_points(f.points+t.reward_points),weekly_points=f.weekly_points+t.reward_points where f.id=m.family_id; end if;
    end if;
  end loop;
end; $$;
grant execute on function public.record_family_task_progress(uuid,text,bigint) to authenticated;
