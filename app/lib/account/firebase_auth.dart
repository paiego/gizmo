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
/// The native config files are not in this repo, so they stay on the list.
List<String> firebaseConfigGaps() {
  final gaps = <String>[
    'app/android/app/google-services.json from the Firebase project',
    'app/ios/Runner/GoogleService-Info.plist from the Firebase project',
    'lib/firebase_options.dart generated for this app',
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

/// Sign-in call site.
///
/// When the SDK is linked this should be:
/// `FirebaseAuth.instance.signInAnonymously()` and then `credential.user.uid`.
/// It does not create a stand-in id.
Future<String> requestFirebaseUserId() async {
  final gaps = firebaseConfigGaps();
  if (gaps.isNotEmpty) {
    throw FirebaseConfigMissing(gaps);
  }
  throw const FirebaseSdkNotLinked();
}
