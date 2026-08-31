# random_mission_app

## Local Supabase configuration

This project never commits Supabase credentials. To run the app locally, copy
`supabase.env.example.json` to `supabase.env.json` and fill in your project
URL and publishable key from Supabase Dashboard → Connect.

Native Google sign-in also requires `GOOGLE_WEB_CLIENT_ID` (Android/iOS) and
`GOOGLE_IOS_CLIENT_ID` (iOS) in that file. The same web client ID must be
enabled in Supabase Authentication → Sign In / Providers → Google. Android
additionally needs a Google OAuth Android client registered for the final app
package name and signing SHA-1.

In VS Code, select **Random Mission App** in the Run and Debug configuration
dropdown and start debugging with F5.

The publishable key is sufficient to run the Flutter client, but it cannot
deploy the database schema. A member of the configured Supabase project must
apply every file in `supabase/migrations` in timestamp order. For team
development, commit migration files and coordinate so only one maintainer
pushes them to the shared remote project.

The signed-in app stores rooms, memberships, daily missions, photos, votes,
profiles, and chat in Supabase. Guest mode is local-only and starts empty.

Email confirmation is enabled on the active project. The built-in Supabase
mailer is only suitable for project-team addresses and has a low rate limit;
configure custom SMTP before testing sign-up with arbitrary users.

## Getting Started

This project is a starting point for a Flutter application.

A few resources to get you started if this is your first Flutter project:

- [Learn Flutter](https://docs.flutter.dev/get-started/learn-flutter)
- [Write your first Flutter app](https://docs.flutter.dev/get-started/codelab)
- [Flutter learning resources](https://docs.flutter.dev/reference/learning-resources)

For help getting started with Flutter development, view the
[online documentation](https://docs.flutter.dev/), which offers tutorials,
samples, guidance on mobile development, and a full API reference.
