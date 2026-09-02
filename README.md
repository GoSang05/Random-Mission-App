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

The shared OAuth clients use Android package and iOS bundle ID
`com.gosang05.doit`. The Google OAuth consent screen is currently in Testing
status, so each teammate's Google account must be added as a test user in the
Google Cloud console before Google sign-in will accept that account.

In VS Code, select **Random Mission App** in the Run and Debug configuration
dropdown and start debugging with F5.

The publishable key is sufficient to run the Flutter client, but it cannot
deploy the database schema. A member of the configured Supabase project must
apply every file in `supabase/migrations` in timestamp order. For team
development, commit migration files and coordinate so only one maintainer
pushes them to the shared remote project.

The signed-in app stores rooms, memberships, daily missions, photos, profiles,
and chat in Supabase, so Android and iOS clients using the same project share
data. Guest mode is local-only and starts empty. Story voting is no longer
shown or written by the app; the existing remote vote table is retained only
for backward compatibility with older builds.

## Android distribution build

Build a shareable APK with the cloud and OAuth values compiled into it:

```powershell
flutter build apk --release --dart-define-from-file=supabase.env.json
```

The generated file is `build/app/outputs/flutter-apk/app-release.apk`. People
installing that exact APK do not need `supabase.env.json`; it is needed only by
developers building the app themselves. Never put a Supabase secret/service
role key or a Google client secret in this file. The Supabase publishable key
and OAuth client IDs are public client configuration.

The current release variant is temporarily signed with this machine's debug
certificate, whose SHA-1 is registered in the Android Google OAuth client.
This makes directly shared APKs work, but it is not a production release
strategy. Before Play Store or long-term distribution, create a permanent
upload/release key, configure Gradle signing, and add its SHA-1 to the Google
OAuth Android client. If Play App Signing is enabled, also register Google's
app-signing certificate SHA-1.

Google OAuth is currently in Testing status. Directly shared builds can use
ID/password login, but Google login is limited to accounts listed as OAuth test
users until the consent screen is published to Production.

The app collects a login ID instead of an email address. Internally it maps the
ID to a Supabase email/password identity, with email confirmation disabled.
Password recovery is not available until a separate recovery method is added.

## Getting Started

This project is a starting point for a Flutter application.

A few resources to get you started if this is your first Flutter project:

- [Learn Flutter](https://docs.flutter.dev/get-started/learn-flutter)
- [Write your first Flutter app](https://docs.flutter.dev/get-started/codelab)
- [Flutter learning resources](https://docs.flutter.dev/reference/learning-resources)

For help getting started with Flutter development, view the
[online documentation](https://docs.flutter.dev/), which offers tutorials,
samples, guidance on mobile development, and a full API reference.
