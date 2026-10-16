import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import '../models/user_model.dart';

class AuthRepository {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseFunctions _functions = FirebaseFunctions.instance;

  Stream<User?> get authStateChanges => _auth.authStateChanges();

  User? get currentFirebaseUser => _auth.currentUser;

  Future<UserModel?> getCurrentUserProfile() async {
    final user = _auth.currentUser;
    if (user == null) return null;

    final doc = await _firestore.collection('users').doc(user.uid).get();
    if (!doc.exists) {
      // Auto-create initial staff profile if user exists in auth but not yet in firestore
      final newUser = UserModel(
        id: user.uid,
        email: user.email ?? '',
        name: user.displayName ?? (user.email?.split('@').first ?? 'Staff'),
        role: 'staff',
        createdAt: DateTime.now(),
      );
      await _firestore.collection('users').doc(user.uid).set(newUser.toMap(), SetOptions(merge: true));
      return newUser;
    }
    return UserModel.fromFirestore(doc);
  }

  Stream<UserModel?> watchCurrentUserProfile() {
    return _auth.authStateChanges().asyncExpand((user) {
      if (user == null) return Stream.value(null);
      return _firestore.collection('users').doc(user.uid).snapshots().map((doc) {
        if (!doc.exists) return null;
        return UserModel.fromFirestore(doc);
      });
    });
  }

  Future<UserCredential> signIn(String email, String password) async {
    return await _auth.signInWithEmailAndPassword(
      email: email.trim(),
      password: password,
    );
  }

  Future<UserCredential> signUp(String email, String password, String name) async {
    final cred = await _auth.createUserWithEmailAndPassword(
      email: email.trim(),
      password: password,
    );
    if (cred.user != null) {
      final userModel = UserModel(
        id: cred.user!.uid,
        email: email.trim(),
        name: name.trim(),
        role: 'staff',
        createdAt: DateTime.now(),
      );
      await _firestore.collection('users').doc(cred.user!.uid).set(userModel.toMap());
    }
    return cred;
  }

  Future<void> signOut() async {
    await _auth.signOut();
  }

  Future<void> sendPasswordResetEmail(String email) async {
    await _auth.sendPasswordResetEmail(email: email.trim());
  }

  Future<bool> bootstrapAdmin(String name) async {
    final user = _auth.currentUser;
    if (user == null) throw Exception('Pengguna harus login terlebih dahulu.');

    try {
      // Try Cloud Function callable first
      final callable = _functions.httpsCallable('bootstrapAdmin');
      final result = await callable.call({'name': name});
      return result.data['success'] == true;
    } catch (_) {
      // Direct Firestore fallback for bootstrapping initial admin if Cloud Functions are not yet deployed
      final adminsSnap = await _firestore.collection('users').where('role', isEqualTo: 'admin').limit(1).get();
      if (adminsSnap.docs.isNotEmpty && adminsSnap.docs.first.id != user.uid) {
        throw Exception('Administrator sudah ada di sistem. Hubungi admin untuk pemberian hak akses.');
      }

      await _firestore.collection('users').doc(user.uid).set({
        'email': user.email ?? '',
        'name': name.isNotEmpty ? name : (user.email?.split('@').first ?? 'Administrator'),
        'role': 'admin',
        'updatedAt': FieldValue.serverTimestamp(),
        'createdAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      await _firestore.collection('activity_logs').add({
        'actorId': user.uid,
        'actorName': user.email ?? 'Admin',
        'action': 'BOOTSTRAP_ADMIN',
        'category': 'SECURITY',
        'details': 'Administrator pertama berhasil di-bootstrap.',
        'timestamp': FieldValue.serverTimestamp(),
      });

      return true;
    }
  }

  Future<List<UserModel>> getAllUsers() async {
    final snap = await _firestore.collection('users').orderBy('createdAt', descending: true).get();
    return snap.docs.map((d) => UserModel.fromFirestore(d)).toList();
  }

  Future<void> updateUserRole(String userId, String newRole) async {
    await _firestore.collection('users').doc(userId).update({
      'role': newRole,
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }
}
