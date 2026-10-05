import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';

/// Everything to do with who is signed in.
///
/// The screens never talk to Firebase Authentication directly - they call this
/// class. Keeping it in one place means there is exactly one version of "how we
/// register a user", and the screens stay about layout rather than about
/// Firebase.
class AuthService {
  /// The Firebase Auth instance for this app. `.instance` hands back the single
  /// shared object rather than creating a new one each time.
  final FirebaseAuth _auth = FirebaseAuth.instance;

  /// A pointer to the "users" branch of the Realtime Database tree. Nothing is
  /// fetched by creating this - it is just an address we can read or write at.
  final DatabaseReference _usersRef = FirebaseDatabase.instance.ref('users');

  /// Whoever is signed in right now, or null if nobody is.
  ///
  /// This is a one-off look at the current value. Use [authStateChanges] when
  /// you want to react to it changing.
  User? get currentUser => _auth.currentUser;

  /// A live stream of the signed-in user, or null when signed out.
  ///
  /// It fires once as soon as it is listened to (with the user restored from
  /// the last session, if any), and again on every sign-in and sign-out. This
  /// is what AuthGate listens to, and it is why the app remembers you after a
  /// restart.
  Stream<User?> authStateChanges() => _auth.authStateChanges();

  /// Creates a new account, then saves the user's profile to the database.
  ///
  /// Takes the display name, email and password typed on the register form.
  /// Throws a [FirebaseAuthException] if Firebase rejects it - for example
  /// because the email is already registered.
  Future<void> register({
    required String name,
    required String email,
    required String password,
  }) async {
    // Step 1: create the account. This also signs the new user in, which means
    // authStateChanges fires and AuthGate moves us into the app automatically.
    final UserCredential credential = await _auth.createUserWithEmailAndPassword(
      email: email.trim(),
      password: password,
    );

    // Step 2: store the name on the Auth account, so the UI can show
    // "Hi, Pasindu" without having to read the database first.
    await credential.user!.updateDisplayName(name.trim());

    // Step 3: write our own record under users/{uid}. Firebase Auth holds the
    // credentials; the Realtime Database is our app's data store, and the brief
    // requires it to be the primary one. Events will later reference this uid.
    //
    // set() writes at an address we choose (the uid), replacing whatever was
    // there. That differs from push(), used for events, which invents a new
    // unique key each time because events have no natural id.
    await _usersRef.child(credential.user!.uid).set({
      'name': name.trim(),
      'email': email.trim(),
      // Stored as milliseconds since 1970 - a plain integer, which sorts
      // correctly and avoids date-format problems across devices.
      'createdAt': DateTime.now().millisecondsSinceEpoch,
    });
  }

  /// Signs an existing user in.
  ///
  /// Throws a [FirebaseAuthException] if the credentials are wrong. On success
  /// nothing is returned - AuthGate notices the change through the stream.
  Future<void> signIn({
    required String email,
    required String password,
  }) async {
    await _auth.signInWithEmailAndPassword(
      email: email.trim(),
      password: password,
    );
  }

  /// Signs the current user out.
  ///
  /// No navigation is needed afterwards: the stream emits null and AuthGate
  /// swaps back to the login screen by itself.
  Future<void> signOut() => _auth.signOut();

  /// Turns a Firebase error code into a sentence a user can act on.
  ///
  /// Firebase reports failures as short codes like 'wrong-password'. Showing
  /// those raw is unfriendly, and the marking scheme asks for errors to be
  /// handled gracefully. Anything we haven't listed falls back to a general
  /// message rather than a crash.
  static String friendlyError(String code) {
    switch (code) {
      case 'email-already-in-use':
        return 'That email already has an account. Try signing in instead.';
      case 'invalid-email':
        return 'That does not look like a valid email address.';
      case 'weak-password':
        return 'Please choose a password of at least 6 characters.';
      case 'user-not-found':
      case 'wrong-password':
      case 'invalid-credential':
        // Firebase deliberately blurs these three together, and so do we:
        // saying "no account with that email" would tell a stranger which
        // email addresses are registered.
        return 'Incorrect email or password.';
      case 'user-disabled':
        return 'This account has been disabled.';
      case 'too-many-requests':
        return 'Too many attempts. Please wait a moment and try again.';
      case 'network-request-failed':
        return 'No internet connection. Please check and try again.';
      default:
        return 'Something went wrong. Please try again.';
    }
  }
}
