# Random Mission MVP status

The Random Mission experience currently runs as a clearly labeled local MVP
preview. Rooms, missions, submissions, votes, and chat reset when the app
restarts. The existing magazine page still uses its existing Supabase calls.

## Included now

- Home loading, empty, error, private-room, global-room, and recent-story UI
- Local room creation and invite-code joining
- Private-room missions, horizontal stories, and basic chat
- Global missions and user-created global missions
- Horizontal story viewer with one vote per preview user and visible totals
- Styled photo/video capture flow with cancellation, permission, progress,
  success, and failure states
- Mobile-flow, repository, and capture-state tests

The MVP is currently portrait-only so the capture controls remain usable on
small phones.

Android activity-death recovery is not connected in this local preview. It
requires persisting the pending room and mission before opening the system
camera so a recovered file cannot be attached to the wrong mission.

## Required before production persistence

No mission schema, migration, RLS policy, Storage policy, or implemented auth
flow exists in this checkout. Before connecting the repository:

1. Provide a current Supabase schema export or approve read-only inspection of
   the remote project.
2. Decide the authentication flow. The current app has no sign-in or sign-up
   implementation to reuse.
3. Review and approve SQL for rooms, room membership, missions, submissions,
   unique per-user votes, chat messages, and a private media bucket. No SQL has
   been created or applied by this MVP work.
4. Replace `LocalMissionRepository` with a Supabase-backed implementation and
   enable Realtime only for chat, votes, and submission updates.
5. Store private media under an authenticated path such as
   `<room-id>/<user-id>/<submission-id>.<extension>` and enforce membership in
   both database and Storage policies.

## Dependency approval still needed

`image_picker` provides the styled flow around the operating system's capture
screen. A live embedded camera preview and in-app video playback require the
uninstalled `camera` and `video_player` packages. The current platform files
include the required camera/photo descriptions and the iOS microphone usage
description for the existing short-video capture flow. Android delegates this
flow to the system camera and needs no app-level microphone permission.
