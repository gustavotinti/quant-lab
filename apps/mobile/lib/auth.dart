import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:google_sign_in/google_sign_in.dart';

/// Login Google + leitura do portfólio real do eToro (Firestore
/// `private/portfolio` — a regra só permite o dono). O app continua 100%
/// funcional sem login; autenticar só liga o Copiloto.
///
/// serverClientId = OAuth client web do projeto (client_type 3 do
/// google-services.json) — exigido pelo google_sign_in v7 p/ idToken.
const _serverClientId =
    '1025412444243-t6or96doo73f02qmj0qc0bagu4c9202a.apps.googleusercontent.com';

Future<void> initFirebase() async {
  await Firebase.initializeApp();
  await GoogleSignIn.instance.initialize(serverClientId: _serverClientId);
}

Future<User?> entrarComGoogle() async {
  final conta = await GoogleSignIn.instance.authenticate();
  final cred = GoogleAuthProvider.credential(
      idToken: conta.authentication.idToken);
  return (await FirebaseAuth.instance.signInWithCredential(cred)).user;
}

Future<void> sair() async {
  await GoogleSignIn.instance.signOut();
  await FirebaseAuth.instance.signOut();
}

User? get usuario {
  try {
    return FirebaseAuth.instance.currentUser;
  } catch (_) {
    return null; // Firebase ainda subindo (ou indisponível na web)
  }
}

/// Portfólio real (null = deslogado, sem permissão ou vazio).
Future<Map<String, dynamic>?> lerPortfolioEtoro() async {
  if (usuario == null) return null;
  try {
    final snap = await FirebaseFirestore.instance
        .doc('private/portfolio')
        .get();
    return snap.data();
  } catch (_) {
    return null; // sem permissão (outra conta) ou offline
  }
}
