/// Supabase settings. The project URL is public, so it is the default here.
/// The anon key is passed at build time and is never stored in the code:
///   flutter run --dart-define=SUPABASE_ANON_KEY=...
/// In GitHub Actions it comes from the repository secret SUPABASE_ANON_KEY.
/// Without the key the app still works, with data kept only on the phone.
const supabaseUrl = String.fromEnvironment(
  'SUPABASE_URL',
  defaultValue: 'https://rofxxebtjrmtrulbkexi.supabase.co',
);
const supabaseAnonKey = String.fromEnvironment('SUPABASE_ANON_KEY');

/// Where Google sign-in sends the user back to the app (Android deep link).
/// Add the same value in Supabase: Authentication, URL Configuration, Redirect URLs.
const oauthRedirect = 'io.supabase.healthy://login-callback/';

bool get cloudEnabled => supabaseUrl.isNotEmpty && supabaseAnonKey.isNotEmpty;

/// Firebase (push notifications). Values come from the Firebase console and are
/// passed at build time from GitHub secrets. Without them the app still works,
/// it just does not register for push messages.
const firebaseApiKey = String.fromEnvironment('FIREBASE_API_KEY');
const firebaseAppId = String.fromEnvironment('FIREBASE_APP_ID');
const firebaseSenderId = String.fromEnvironment('FIREBASE_SENDER_ID');
const firebaseProjectId = String.fromEnvironment('FIREBASE_PROJECT_ID');

bool get pushEnabled =>
    cloudEnabled &&
    firebaseApiKey.isNotEmpty &&
    firebaseAppId.isNotEmpty &&
    firebaseSenderId.isNotEmpty &&
    firebaseProjectId.isNotEmpty;
