# Random Mission backend status

The signed-in application is designed to use Supabase for authentication,
rooms, room membership, daily missions, photo submissions, profiles,
and realtime chat. Mission photos and profile avatars use private Supabase
Storage buckets with RLS policies.

Guest mode remains a local-only development convenience. It starts empty and
does not include bundled preview rooms, submissions, or messages.

Story approval/rejection voting is no longer exposed by the current app. The
legacy database objects remain temporarily for compatibility with older builds.

## Remote deployment

All migrations in `supabase/migrations` were applied on 2026-08-31 to the
active `GoSang05's Project` Supabase project (`vzlzrpghnrmncwvfhdil`):

1. `202608250001_create_chat.sql`
2. `202608310001_create_mission_backend.sql`
3. `202608310002_sync_profile_names.sql`
4. `202608310003_leave_room.sql`

The second migration created the mission tables, RPCs, realtime publication
entries, and the private `mission-photos` and `profile-avatars` buckets.
The third migration keeps existing chat sender names synchronized with profile
changes and publishes profile updates through Realtime.
The fourth adds room leaving/system messages, owner-only room renaming, and
member lookup.

## Authentication status

ID/password signup, login, and confirmed logout are implemented. The ID is
mapped to an internal Supabase email identity because Supabase password auth
does not natively support usernames. Confirm email is disabled; a separate
password recovery method is still required before production launch.

The native Google account-picker code and UI are implemented. Google OAuth is
not yet active because the Google web/iOS client IDs are empty and the Google
provider is disabled in Supabase. Final activation requires selecting a stable
application ID, registering its Android SHA-1 in Google Cloud, and adding the
resulting OAuth credentials to Supabase and `supabase.env.json`.

`supabase.env.json` is intentionally ignored by Git. Every clone needs a local
copy with this project's URL and publishable key, or must point to a separately
migrated Supabase project. Never use a service-role key in the Flutter app.

## Local persistence that remains

Guest rooms and guest profile data use device storage. Camera photos are first
optimized locally before signed-in uploads. The product now focuses only on
random mission rooms; the Magazine screen and its local data store were removed.

## Verification

Run:

```powershell
flutter analyze
flutter test
flutter run --dart-define-from-file=supabase.env.json
```
