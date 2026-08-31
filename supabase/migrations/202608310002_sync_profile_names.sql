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
      and sender_display_name is distinct from new.display_name;
  end if;
  return new;
end;
$$;

drop trigger if exists sync_profile_display_name_on_update
  on public.chat_profiles;
create trigger sync_profile_display_name_on_update
after update of display_name on public.chat_profiles
for each row
execute function public.sync_profile_display_name();

do $$
begin
  alter publication supabase_realtime add table public.chat_profiles;
exception
  when duplicate_object then null;
end;
$$;
