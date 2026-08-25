create extension if not exists pgcrypto;

create table if not exists public.chat_profiles (
  user_id uuid primary key references auth.users(id) on delete cascade,
  display_name text not null check (char_length(display_name) between 1 and 40),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table if not exists public.chat_conversations (
  id uuid primary key default gen_random_uuid(),
  kind text not null check (kind in ('global', 'room', 'direct')),
  title text check (title is null or char_length(title) between 1 and 80),
  room_id text unique check (room_id is null or char_length(room_id) between 1 and 160),
  direct_key text unique,
  created_by uuid references auth.users(id) on delete set null,
  created_at timestamptz not null default now(),
  constraint chat_conversation_shape check (
    (kind = 'global' and room_id is null and direct_key is null)
    or (kind = 'room' and room_id is not null and direct_key is null)
    or (kind = 'direct' and room_id is null and direct_key is not null)
  )
);

create unique index if not exists one_global_chat
  on public.chat_conversations (kind)
  where kind = 'global';

create table if not exists public.chat_conversation_members (
  conversation_id uuid not null references public.chat_conversations(id) on delete cascade,
  user_id uuid not null references auth.users(id) on delete cascade,
  joined_at timestamptz not null default now(),
  primary key (conversation_id, user_id)
);

create index if not exists chat_members_by_user
  on public.chat_conversation_members (user_id, joined_at desc);

create table if not exists public.chat_room_invites (
  conversation_id uuid primary key references public.chat_conversations(id) on delete cascade,
  invite_code text not null unique check (invite_code ~ '^[A-Z0-9]{4,12}$'),
  created_at timestamptz not null default now()
);

create table if not exists public.chat_messages (
  id uuid primary key default gen_random_uuid(),
  conversation_id uuid not null references public.chat_conversations(id) on delete cascade,
  sender_id uuid not null references auth.users(id) on delete cascade,
  sender_display_name text not null check (char_length(sender_display_name) between 1 and 40),
  body text not null check (char_length(btrim(body)) between 1 and 500),
  created_at timestamptz not null default now()
);

create index if not exists chat_messages_by_conversation
  on public.chat_messages (conversation_id, created_at desc);

create table if not exists public.chat_blocks (
  blocker_id uuid not null references auth.users(id) on delete cascade,
  blocked_id uuid not null references auth.users(id) on delete cascade,
  created_at timestamptz not null default now(),
  primary key (blocker_id, blocked_id),
  constraint cannot_block_self check (blocker_id <> blocked_id)
);

create table if not exists public.chat_message_reports (
  id uuid primary key default gen_random_uuid(),
  message_id uuid not null references public.chat_messages(id) on delete cascade,
  reporter_id uuid not null references auth.users(id) on delete cascade,
  reason text not null default 'inappropriate',
  created_at timestamptz not null default now(),
  unique (message_id, reporter_id)
);

insert into public.chat_conversations (id, kind, title)
values ('00000000-0000-0000-0000-000000000001', 'global', 'Global Chat')
on conflict do nothing;

alter table public.chat_profiles enable row level security;
alter table public.chat_conversations enable row level security;
alter table public.chat_conversation_members enable row level security;
alter table public.chat_room_invites enable row level security;
alter table public.chat_messages enable row level security;
alter table public.chat_blocks enable row level security;
alter table public.chat_message_reports enable row level security;

create or replace function public.is_chat_member(
  p_conversation_id uuid
)
returns boolean
language sql
stable
security definer
set search_path = public, pg_temp
as $$
  select exists (
    select 1
    from public.chat_conversation_members
    where conversation_id = p_conversation_id
      and user_id = auth.uid()
  );
$$;

create or replace function public.is_chat_blocked(p_other_user_id uuid)
returns boolean
language sql
stable
security definer
set search_path = public, pg_temp
as $$
  select exists (
    select 1
    from public.chat_blocks blocked_pair
    where (blocked_pair.blocker_id = auth.uid()
      and blocked_pair.blocked_id = p_other_user_id)
       or (blocked_pair.blocker_id = p_other_user_id
      and blocked_pair.blocked_id = auth.uid())
  );
$$;

drop policy if exists "profiles_select_own" on public.chat_profiles;
create policy "profiles_select_own"
  on public.chat_profiles for select
  to authenticated
  using (user_id = auth.uid());

drop policy if exists "profiles_update_own" on public.chat_profiles;
create policy "profiles_update_own"
  on public.chat_profiles for update
  to authenticated
  using (user_id = auth.uid())
  with check (user_id = auth.uid());

drop policy if exists "conversations_select_accessible" on public.chat_conversations;
create policy "conversations_select_accessible"
  on public.chat_conversations for select
  to authenticated
  using (kind = 'global' or public.is_chat_member(id));

drop policy if exists "members_select_own" on public.chat_conversation_members;
create policy "members_select_own"
  on public.chat_conversation_members for select
  to authenticated
  using (user_id = auth.uid());

drop policy if exists "messages_select_accessible" on public.chat_messages;
create policy "messages_select_accessible"
  on public.chat_messages for select
  to authenticated
  using (
    not public.is_chat_blocked(sender_id)
    and
    exists (
      select 1
      from public.chat_conversations conversation
      where conversation.id = chat_messages.conversation_id
        and (
          conversation.kind = 'global'
          or public.is_chat_member(conversation.id)
        )
    )
  );

create or replace function public.handle_new_chat_user()
returns trigger
language plpgsql
security definer
set search_path = public, pg_temp
as $$
declare
  profile_name text;
begin
  profile_name := btrim(coalesce(new.raw_user_meta_data ->> 'display_name', ''));
  if profile_name = '' then
    profile_name := split_part(coalesce(new.email, '사용자'), '@', 1);
  end if;
  profile_name := left(profile_name, 40);

  insert into public.chat_profiles (user_id, display_name)
  values (new.id, profile_name)
  on conflict (user_id) do nothing;
  return new;
end;
$$;

drop trigger if exists on_auth_user_created_create_chat_profile on auth.users;
create trigger on_auth_user_created_create_chat_profile
  after insert on auth.users
  for each row execute function public.handle_new_chat_user();

create or replace function public.ensure_chat_profile(p_display_name text)
returns void
language plpgsql
security definer
set search_path = public, pg_temp
as $$
declare
  clean_name text := btrim(p_display_name);
begin
  if auth.uid() is null then
    raise exception 'authentication_required';
  end if;
  if char_length(clean_name) not between 1 and 40 then
    raise exception 'invalid_display_name';
  end if;

  insert into public.chat_profiles (user_id, display_name)
  values (auth.uid(), clean_name)
  on conflict (user_id) do update
    set display_name = excluded.display_name,
        updated_at = now();
end;
$$;

create or replace function public.get_global_chat()
returns uuid
language plpgsql
stable
security definer
set search_path = public, pg_temp
as $$
begin
  if auth.uid() is null then
    raise exception 'authentication_required';
  end if;
  return '00000000-0000-0000-0000-000000000001'::uuid;
end;
$$;

create or replace function public.register_room_chat(
  p_room_id text,
  p_room_name text,
  p_invite_code text
)
returns uuid
language plpgsql
security definer
set search_path = public, pg_temp
as $$
declare
  clean_room_id text := btrim(p_room_id);
  clean_room_name text := btrim(p_room_name);
  clean_invite_code text := upper(btrim(p_invite_code));
  conversation public.chat_conversations%rowtype;
begin
  if auth.uid() is null then
    raise exception 'authentication_required';
  end if;
  if char_length(clean_room_id) not between 1 and 160
    or char_length(clean_room_name) not between 1 and 80
    or clean_invite_code !~ '^[A-Z0-9]{4,12}$' then
    raise exception 'invalid_room';
  end if;

  select * into conversation
  from public.chat_conversations
  where room_id = clean_room_id;

  if conversation.id is null then
    begin
      insert into public.chat_conversations (kind, title, room_id, created_by)
      values ('room', clean_room_name, clean_room_id, auth.uid())
      returning * into conversation;

      insert into public.chat_room_invites (conversation_id, invite_code)
      values (conversation.id, clean_invite_code);
    exception
      when unique_violation then
        select * into conversation
        from public.chat_conversations
        where room_id = clean_room_id;
        if conversation.id is null then
          raise exception 'invite_code_in_use';
        end if;
    end;
  end if;

  if conversation.created_by = auth.uid()
    or public.is_chat_member(conversation.id) then
    insert into public.chat_conversation_members (conversation_id, user_id)
    values (conversation.id, auth.uid())
    on conflict do nothing;
    return conversation.id;
  end if;

  raise exception 'not_a_room_member';
end;
$$;

create or replace function public.join_room_chat(p_invite_code text)
returns table (
  room_id text,
  room_name text,
  invite_code text,
  member_count bigint
)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
declare
  clean_invite_code text := upper(btrim(p_invite_code));
  target_id uuid;
begin
  if auth.uid() is null then
    raise exception 'authentication_required';
  end if;
  if clean_invite_code !~ '^[A-Z0-9]{4,12}$' then
    raise exception 'invalid_invite';
  end if;

  select conversation.id into target_id
  from public.chat_room_invites invite
  join public.chat_conversations conversation
    on conversation.id = invite.conversation_id
  where invite.invite_code = clean_invite_code
    and conversation.kind = 'room';

  if target_id is null then
    raise exception 'invalid_invite';
  end if;

  insert into public.chat_conversation_members (conversation_id, user_id)
  values (target_id, auth.uid())
  on conflict do nothing;

  return query
  select conversation.room_id,
         conversation.title,
         clean_invite_code,
         count(member.user_id)
  from public.chat_conversations conversation
  join public.chat_conversation_members member
    on member.conversation_id = conversation.id
  where conversation.id = target_id
  group by conversation.id, conversation.room_id, conversation.title;
end;
$$;

create or replace function public.list_joined_room_chats()
returns table (
  room_id text,
  room_name text,
  invite_code text,
  member_count bigint
)
language sql
stable
security definer
set search_path = public, pg_temp
as $$
  select conversation.room_id,
         conversation.title,
         invite.invite_code,
         count(all_members.user_id)
  from public.chat_conversations conversation
  join public.chat_conversation_members mine
    on mine.conversation_id = conversation.id
   and mine.user_id = auth.uid()
  join public.chat_room_invites invite
    on invite.conversation_id = conversation.id
  join public.chat_conversation_members all_members
    on all_members.conversation_id = conversation.id
  where auth.uid() is not null
    and conversation.kind = 'room'
  group by conversation.id,
           conversation.room_id,
           conversation.title,
           invite.invite_code,
           conversation.created_at
  order by conversation.created_at desc;
$$;

create or replace function public.find_chat_profiles(p_search text default '')
returns table (user_id uuid, display_name text)
language sql
stable
security definer
set search_path = public, pg_temp
as $$
  select profile.user_id, profile.display_name
  from public.chat_profiles profile
  where auth.uid() is not null
    and profile.user_id <> auth.uid()
    and not public.is_chat_blocked(profile.user_id)
    and (
      btrim(p_search) = ''
      or position(lower(btrim(p_search)) in lower(profile.display_name)) > 0
    )
  order by profile.display_name
  limit 30;
$$;

create or replace function public.get_or_create_direct_chat(p_other_user_id uuid)
returns uuid
language plpgsql
security definer
set search_path = public, pg_temp
as $$
declare
  key text;
  conversation_id uuid;
begin
  if auth.uid() is null then
    raise exception 'authentication_required';
  end if;
  if p_other_user_id is null or p_other_user_id = auth.uid() then
    raise exception 'invalid_recipient';
  end if;
  if not exists (
    select 1 from public.chat_profiles where user_id = p_other_user_id
  ) then
    raise exception 'recipient_not_found';
  end if;
  if public.is_chat_blocked(p_other_user_id) then
    raise exception 'user_blocked';
  end if;

  key := least(auth.uid()::text, p_other_user_id::text)
    || ':' || greatest(auth.uid()::text, p_other_user_id::text);

  insert into public.chat_conversations (kind, direct_key, created_by)
  values ('direct', key, auth.uid())
  on conflict (direct_key) do update set direct_key = excluded.direct_key
  returning id into conversation_id;

  insert into public.chat_conversation_members (conversation_id, user_id)
  values
    (conversation_id, auth.uid()),
    (conversation_id, p_other_user_id)
  on conflict do nothing;

  return conversation_id;
end;
$$;

create or replace function public.list_direct_chats()
returns table (
  conversation_id uuid,
  other_user_id uuid,
  other_display_name text,
  last_message text,
  last_message_at timestamptz
)
language sql
stable
security definer
set search_path = public, pg_temp
as $$
  select conversation.id,
         other_member.user_id,
         profile.display_name,
         latest.body,
         latest.created_at
  from public.chat_conversations conversation
  join public.chat_conversation_members mine
    on mine.conversation_id = conversation.id
   and mine.user_id = auth.uid()
  join public.chat_conversation_members other_member
    on other_member.conversation_id = conversation.id
   and other_member.user_id <> auth.uid()
  join public.chat_profiles profile
    on profile.user_id = other_member.user_id
  left join lateral (
    select message.body, message.created_at
    from public.chat_messages message
    where message.conversation_id = conversation.id
    order by message.created_at desc
    limit 1
  ) latest on true
  where auth.uid() is not null
    and conversation.kind = 'direct'
    and not public.is_chat_blocked(other_member.user_id)
  order by latest.created_at desc nulls last, conversation.created_at desc;
$$;

create or replace function public.send_chat_message(
  p_conversation_id uuid,
  p_body text
)
returns uuid
language plpgsql
security definer
set search_path = public, pg_temp
as $$
declare
  clean_body text := btrim(p_body);
  conversation_kind text;
  display_name text;
  new_message_id uuid;
begin
  if auth.uid() is null then
    raise exception 'authentication_required';
  end if;
  if char_length(clean_body) not between 1 and 500 then
    raise exception 'invalid_message';
  end if;

  select kind into conversation_kind
  from public.chat_conversations
  where id = p_conversation_id;

  if conversation_kind is null
    or (conversation_kind <> 'global'
      and not public.is_chat_member(p_conversation_id)) then
    raise exception 'not_a_chat_member';
  end if;

  if conversation_kind = 'direct' and exists (
    select 1
    from public.chat_conversation_members member
    where member.conversation_id = p_conversation_id
      and member.user_id <> auth.uid()
      and public.is_chat_blocked(member.user_id)
  ) then
    raise exception 'user_blocked';
  end if;

  if (
    select count(*)
    from public.chat_messages
    where sender_id = auth.uid()
      and created_at > now() - interval '1 minute'
  ) >= 20 then
    raise exception 'rate_limit';
  end if;

  select profile.display_name into display_name
  from public.chat_profiles profile
  where profile.user_id = auth.uid();
  if display_name is null then
    raise exception 'profile_required';
  end if;

  insert into public.chat_messages (
    conversation_id,
    sender_id,
    sender_display_name,
    body
  ) values (
    p_conversation_id,
    auth.uid(),
    display_name,
    clean_body
  ) returning id into new_message_id;

  return new_message_id;
end;
$$;

create or replace function public.block_chat_user(p_user_id uuid)
returns void
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if auth.uid() is null then
    raise exception 'authentication_required';
  end if;
  if p_user_id is null or p_user_id = auth.uid() then
    raise exception 'invalid_user';
  end if;
  if not exists (select 1 from public.chat_profiles where user_id = p_user_id) then
    raise exception 'user_not_found';
  end if;

  insert into public.chat_blocks (blocker_id, blocked_id)
  values (auth.uid(), p_user_id)
  on conflict do nothing;
end;
$$;

create or replace function public.report_chat_message(p_message_id uuid)
returns void
language plpgsql
security definer
set search_path = public, pg_temp
as $$
declare
  target public.chat_messages%rowtype;
  conversation_kind text;
begin
  if auth.uid() is null then
    raise exception 'authentication_required';
  end if;

  select * into target
  from public.chat_messages
  where id = p_message_id;

  if target.id is null or target.sender_id = auth.uid() then
    raise exception 'message_not_reportable';
  end if;

  select kind into conversation_kind
  from public.chat_conversations
  where id = target.conversation_id;

  if conversation_kind <> 'global'
    and not public.is_chat_member(target.conversation_id) then
    raise exception 'message_not_accessible';
  end if;

  insert into public.chat_message_reports (message_id, reporter_id)
  values (target.id, auth.uid())
  on conflict (message_id, reporter_id) do nothing;
end;
$$;

revoke all on public.chat_profiles from anon;
revoke all on public.chat_conversations from anon;
revoke all on public.chat_conversation_members from anon;
revoke all on public.chat_room_invites from anon;
revoke all on public.chat_messages from anon;
revoke all on public.chat_blocks from anon;
revoke all on public.chat_message_reports from anon;

grant select, update on public.chat_profiles to authenticated;
grant select on public.chat_conversations to authenticated;
grant select on public.chat_conversation_members to authenticated;
grant select on public.chat_messages to authenticated;

revoke all on function public.is_chat_member(uuid) from public;
revoke all on function public.is_chat_blocked(uuid) from public;
revoke all on function public.handle_new_chat_user() from public;
revoke all on function public.ensure_chat_profile(text) from public;
revoke all on function public.get_global_chat() from public;
revoke all on function public.register_room_chat(text, text, text) from public;
revoke all on function public.join_room_chat(text) from public;
revoke all on function public.list_joined_room_chats() from public;
revoke all on function public.find_chat_profiles(text) from public;
revoke all on function public.get_or_create_direct_chat(uuid) from public;
revoke all on function public.list_direct_chats() from public;
revoke all on function public.send_chat_message(uuid, text) from public;
revoke all on function public.block_chat_user(uuid) from public;
revoke all on function public.report_chat_message(uuid) from public;

grant execute on function public.ensure_chat_profile(text) to authenticated;
grant execute on function public.is_chat_member(uuid) to authenticated;
grant execute on function public.is_chat_blocked(uuid) to authenticated;
grant execute on function public.get_global_chat() to authenticated;
grant execute on function public.register_room_chat(text, text, text) to authenticated;
grant execute on function public.join_room_chat(text) to authenticated;
grant execute on function public.list_joined_room_chats() to authenticated;
grant execute on function public.find_chat_profiles(text) to authenticated;
grant execute on function public.get_or_create_direct_chat(uuid) to authenticated;
grant execute on function public.list_direct_chats() to authenticated;
grant execute on function public.send_chat_message(uuid, text) to authenticated;
grant execute on function public.block_chat_user(uuid) to authenticated;
grant execute on function public.report_chat_message(uuid) to authenticated;

do $$
begin
  alter publication supabase_realtime add table public.chat_messages;
exception
  when duplicate_object then null;
end;
$$;
