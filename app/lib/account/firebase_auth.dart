import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:google_sign_in/google_sign_in.dart';

import '../firebase_options.dart';

/// The app process has not called [Firebase.initializeApp] yet.
class FirebaseNotStarted implements Exception {
  const FirebaseNotStarted();

  @override
  String toString() => 'Firebase has not been started.';
}

/// The person closed the Google account picker.
class GoogleSignInCanceled implements Exception {
  const GoogleSignInCanceled();

  @override
  String toString() => 'Sign-in was canceled.';
}

bool firebaseIsReady() {
  try {
    return Firebase.apps.isNotEmpty;
  } catch (_) {
    return false;
  }
}

var _googleReady = false;

Future<GoogleSignIn> _google() async {
  final google = GoogleSignIn.instance;
  if (!_googleReady) {
    final clientId = DefaultFirebaseOptions.currentPlatform.iosClientId;
    if (clientId == null || clientId.isEmpty) {
      throw StateError('The iOS Google client id is missing.');
    }
    await google.initialize(clientId: clientId);
    _googleReady = true;
  }
  return google;
}

/// Signs in with Google and returns the Firebase Auth user id.
///
/// Does not invent an id. A canceled picker or a missing Firebase app throws.
Future<String> requestFirebaseUserId() async {
  if (!firebaseIsReady()) {
    throw const FirebaseNotStarted();
  }
  final google = await _google();
  final GoogleSignInAccount account;
  try {
    account = await google.authenticate();
  } on GoogleSignInException catch (error) {
    if (error.code == GoogleSignInExceptionCode.canceled) {
      throw const GoogleSignInCanceled();
    }
    rethrow;
  }
  final idToken = account.authentication.idToken;
  if (idToken == null || idToken.isEmpty) {
    throw StateError('Google did not return an id token.');
  }
  final credential = GoogleAuthProvider.credential(idToken: idToken);
  final signedIn = await FirebaseAuth.instance.signInWithCredential(credential);
  final uid = signedIn.user?.uid;
  if (uid == null || uid.isEmpty) {
    throw StateError('Firebase did not return a user id.');
  }
  return uid;
}

/// Signs out of Firebase and Google. Local account data is cleared separately.
Future<void> signOutFirebase() async {
  try {
    if (firebaseIsReady()) {
      await FirebaseAuth.instance.signOut();
    }
  } catch (_) {}
  try {
    await GoogleSignIn.instance.signOut();
  } catch (_) {}
}
