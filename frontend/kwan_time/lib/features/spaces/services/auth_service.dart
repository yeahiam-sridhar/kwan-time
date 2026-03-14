import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';

class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final GoogleSignIn _google = GoogleSignIn();

  Future<UserCredential?> signInWithGoogle() async {
    final gUser = await _google.signIn();
    if (gUser == null) {
      return null;
    }

    final gAuth = await gUser.authentication;
    final credential = GoogleAuthProvider.credential(
      accessToken: gAuth.accessToken,
      idToken: gAuth.idToken,
    );
    return _auth.signInWithCredential(credential);
  }

  Future<UserCredential> signInWithEmail(
    String email,
    String password,
  ) =>
      _auth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );

  Future<UserCredential> registerWithEmail(
    String email,
    String password,
  ) =>
      _auth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );

  Future<void> signOut() async {
    await _google.signOut();
    await _auth.signOut();
  }
}
