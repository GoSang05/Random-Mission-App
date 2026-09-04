begin;

alter table public.daily_room_missions
  drop constraint daily_room_missions_slot_check;
alter table public.daily_room_missions
  add constraint daily_room_missions_slot_check check (slot between 1 and 6);

create or replace function public.ensure_daily_room_missions(p_room_id uuid)
returns void
language plpgsql
security definer
set search_path = public, pg_temp
as $$
declare
  today date := (now() at time zone 'Asia/Seoul')::date;
begin
  if auth.uid() is null then
    raise exception 'authentication_required';
  end if;
  if not public.is_mission_room_member(p_room_id) then
    raise exception 'not_a_room_member';
  end if;

  -- Serialize allocation within a room. Keep existing assignments and photos,
  -- even if the active catalog has changed since today's first three missions.
  perform 1 from public.mission_rooms where id = p_room_id for update;

  with available_slots as (
    select slot, row_number() over (order by slot) as position
    from generate_series(1, 6) as slots(slot)
    where not exists (
      select 1 from public.daily_room_missions existing
      where existing.room_id = p_room_id
        and existing.mission_date = today
        and existing.slot = slots.slot
    )
  ), candidates as (
    select catalog.id,
           row_number() over (
             order by md5(p_room_id::text || today::text || catalog.id::text), catalog.id
           ) as position
    from public.mission_catalog catalog
    where catalog.active
      and not exists (
        select 1 from public.daily_room_missions existing
        where existing.room_id = p_room_id
          and existing.mission_date = today
          and existing.catalog_id = catalog.id
      )
  )
  insert into public.daily_room_missions (room_id, mission_date, slot, catalog_id)
  select p_room_id, today, slots.slot, candidates.id
  from available_slots slots
  join candidates using (position)
  on conflict do nothing;
end;
$$;

commit;
