alter table public.chat_messages
  add column if not exists message_kind text not null default 'user';

alter table public.chat_messages
  drop constraint if exists chat_messages_message_kind_check;
alter table public.chat_messages
  add constraint chat_messages_message_kind_check
  check (message_kind in ('user', 'system'));

create or replace function public.sync_profile_display_name()
returns trigger
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if new.display_name is distinct from old.display_name then
    update public.chat_messages
    set sender_display_name = new.display_name
    where sender_id = new.user_id
      and message_kind = 'user'
      and sender_display_name is distinct from new.display_name;
  end if;
  return new;
end;
$$;

create or replace function public.leave_mission_room(p_room_id uuid)
returns void
language plpgsql
security definer
set search_path = public, pg_temp
as $$
declare
  target public.mission_rooms%rowtype;
  leaving_name text;
begin
  if auth.uid() is null then
    raise exception 'authentication_required';
  end if;

  select * into target
  from public.mission_rooms
  where id = p_room_id;

  if target.id is null then
    raise exception 'room_not_found';
  end if;
  if target.kind = 'global' then
    raise exception 'cannot_leave_global_room';
  end if;
  if not exists (
    select 1 from public.mission_room_members
    where room_id = p_room_id and user_id = auth.uid()
  ) then
    raise exception 'not_a_room_member';
  end if;

  select display_name into leaving_name
  from public.chat_profiles
  where user_id = auth.uid();

  insert into public.chat_messages (
    conversation_id,
    sender_id,
    sender_display_name,
    body,
    message_kind
  ) values (
    target.chat_conversation_id,
    auth.uid(),
    '알림',
    coalesce(leaving_name, '사용자') || '님이 방을 나갔어요.',
    'system'
  );

  delete from public.chat_conversation_members
  where conversation_id = target.chat_conversation_id
    and user_id = auth.uid();

  delete from public.mission_room_members
  where room_id = p_room_id
    and user_id = auth.uid();
end;
$$;

revoke all on function public.leave_mission_room(uuid) from public;
grant execute on function public.leave_mission_room(uuid) to authenticated;

create or replace function public.rename_mission_room(
  p_room_id uuid,
  p_name text
)
returns void
language plpgsql
security definer
set search_path = public, pg_temp
as $$
declare
  clean_name text := btrim(p_name);
  target_conversation_id uuid;
begin
  if auth.uid() is null then
    raise exception 'authentication_required';
  end if;
  if char_length(clean_name) not between 1 and 40 then
    raise exception 'invalid_room_name';
  end if;

  select chat_conversation_id into target_conversation_id
  from public.mission_rooms
  where id = p_room_id
    and kind = 'private'
    and created_by = auth.uid();

  if target_conversation_id is null then
    raise exception 'owner_required';
  end if;

  update public.mission_rooms set name = clean_name where id = p_room_id;
  update public.chat_conversations
  set title = clean_name
  where id = target_conversation_id;
end;
$$;

create or replace function public.list_mission_room_members(p_room_id uuid)
returns table (
  user_id uuid,
  display_name text,
  joined_at timestamptz,
  is_owner boolean
)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if auth.uid() is null then
    raise exception 'authentication_required';
  end if;
  if not exists (
    select 1 from public.mission_room_members
    where room_id = p_room_id and user_id = auth.uid()
  ) then
    raise exception 'not_a_room_member';
  end if;

  return query
  select
    member.user_id,
    profile.display_name,
    member.joined_at,
    room.created_by = member.user_id
  from public.mission_room_members member
  join public.chat_profiles profile on profile.user_id = member.user_id
  join public.mission_rooms room on room.id = member.room_id
  where member.room_id = p_room_id
  order by (room.created_by = member.user_id) desc, member.joined_at;
end;
$$;

revoke all on function public.rename_mission_room(uuid, text) from public;
revoke all on function public.list_mission_room_members(uuid) from public;
grant execute on function public.rename_mission_room(uuid, text) to authenticated;
grant execute on function public.list_mission_room_members(uuid) to authenticated;
