/// What is still required before Firebase Auth can issue an account id.
///
/// Nothing here is a credential. The project files and the SDK are absent,
/// and compile-time `FIREBASE_*` values are empty unless a build injects them.
class FirebaseConfigMissing implements Exception {
  const FirebaseConfigMissing(this.missing);

  final List<String> missing;

  @override
  String toString() => missing.join('\n');
}

/// The Firebase packages are not linked, so there is no Auth instance to call.
class FirebaseSdkNotLinked implements Exception {
  const FirebaseSdkNotLinked();

  @override
  String toString() =>
      'firebase_core and firebase_auth are not dependencies yet.';
}

/// Files, packages, and build values a real Firebase Auth setup still needs.
///
/// iOS is the first platform. Android's google-services.json is not required
/// yet. The iOS config is not in this repo, so it stays on the list.
List<String> firebaseConfigGaps() {
  final gaps = <String>[
    'app/ios/Runner/GoogleService-Info.plist from the Firebase project',
    'lib/firebase_options.dart generated for this iOS app',
    'pubspec dependencies firebase_core and firebase_auth',
  ];
  if (!firebaseEnvironmentReady) {
    gaps.add(
      'FIREBASE_API_KEY, FIREBASE_APP_ID, FIREBASE_MESSAGING_SENDER_ID, and FIREBASE_PROJECT_ID supplied at build time',
    );
  }
  return gaps;
}

bool get firebaseEnvironmentReady {
  const apiKey = String.fromEnvironment('FIREBASE_API_KEY');
  const appId = String.fromEnvironment('FIREBASE_APP_ID');
  const sender = String.fromEnvironment('FIREBASE_MESSAGING_SENDER_ID');
  const project = String.fromEnvironment('FIREBASE_PROJECT_ID');
  return apiKey.isNotEmpty &&
      appId.isNotEmpty &&
      sender.isNotEmpty &&
      project.isNotEmpty;
}

/// Sign-in call site for the iOS app.
///
/// When the SDK is linked this should sign in with Google and then read
/// `credential.user.uid`. It does not create a stand-in id.
Future<String> requestFirebaseUserId() async {
  final gaps = firebaseConfigGaps();
  if (gaps.isNotEmpty) {
    throw FirebaseConfigMissing(gaps);
  }
  throw const FirebaseSdkNotLinked();
}
