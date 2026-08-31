# Random Mission backend status

The signed-in application is designed to use Supabase for authentication,
rooms, room membership, daily missions, photo submissions, votes, profiles,
and realtime chat. Mission photos and profile avatars use private Supabase
Storage buckets with RLS policies.

Guest mode remains a local-only development convenience. It starts empty and
does not include bundled preview rooms, submissions, votes, or messages.

## Remote deployment

All migrations in `supabase/migrations` were applied on 2026-08-31 to the
active `GoSang05's Project` Supabase project (`vzlzrpghnrmncwvfhdil`):

1. `202608250001_create_chat.sql`
2. `202608310001_create_mission_backend.sql`
3. `202608310002_sync_profile_names.sql`

The second migration created the mission tables, RPCs, realtime publication
entries, and the private `mission-photos` and `profile-avatars` buckets.
The third migration keeps existing chat sender names synchronized with profile
changes and publishes profile updates through Realtime.

## Authentication status

Email/password signup, confirmation waiting, resend, confirmation checking,
login, and confirmed logout are implemented. Supabase email confirmation is
enabled, but the project still uses the restricted default mailer; custom SMTP
is required for arbitrary public email addresses.

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
optimized locally before signed-in uploads. The Magazine screen continues to
store its personal layout selection locally; its UI has not been changed.

## Verification

Run:

```powershell
flutter analyze
flutter test
flutter run --dart-define-from-file=supabase.env.json
```
