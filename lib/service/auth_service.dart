import 'package:google_sign_in/google_sign_in.dart'
    as gSign; // Tambahkan 'as gSign'
import 'package:firebase_auth/firebase_auth.dart';

class AuthService {
  //Google Signinya
  final gSign.GoogleSignIn _googleSignIn = gSign.GoogleSignIn();

  Future<UserCredential?> signinWithGoogle() async {
    try {
      //proses login make prefix
      final gSign.GoogleSignInAccount? user = await _googleSignIn.signIn();
      if (user == null) return null;

      //Ambil detail authnya
      final gSign.GoogleSignInAuthentication googleAuth =
          await user.authentication;

      //Buat kredensial buat user nanti ini(accessToken & idToken sekarang pasti terbaca)
      final credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );

      return await FirebaseAuth.instance.signInWithCredential(credential);
    } catch (e) {
      print("Error detail: $e");
      return null;
    }
  }
}
