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

    final isSuperAdmin = (user.email?.toLowerCase().trim() == UserModel.superAdminEmail);

    final doc = await _firestore.collection('users').doc(user.uid).get();
    if (!doc.exists) {
      // Check if any admin exists in the system
      final adminsSnap = await _firestore.collection('users').where('role', isEqualTo: 'admin').limit(1).get();
      final isFirstAdmin = adminsSnap.docs.isEmpty;

      // Auto-create initial profile
      final newUser = UserModel(
        id: user.uid,
        email: user.email ?? '',
        name: user.displayName ?? (user.email?.split('@').first ?? (isSuperAdmin ? 'Super Administrator' : 'Staff')),
        role: isSuperAdmin ? 'superadmin' : (isFirstAdmin ? 'admin' : 'staff'),
        createdAt: DateTime.now(),
      );
      await _firestore.collection('users').doc(user.uid).set(newUser.toMap(), SetOptions(merge: true));
      return newUser;
    }

    final userModel = UserModel.fromFirestore(doc);
    // Ensure Super Admin email or initial user has highest rank
    if (isSuperAdmin && userModel.role != 'superadmin') {
      await _firestore.collection('users').doc(user.uid).update({
        'role': 'superadmin',
        'updatedAt': FieldValue.serverTimestamp(),
      });
      return UserModel(
        id: userModel.id,
        email: userModel.email,
        name: userModel.name,
        role: 'superadmin',
        createdAt: userModel.createdAt,
        updatedAt: DateTime.now(),
      );
    } else if (!isSuperAdmin && userModel.role != 'admin') {
      final adminsSnap = await _firestore.collection('users').where('role', isEqualTo: 'admin').limit(1).get();
      if (adminsSnap.docs.isEmpty) {
        await _firestore.collection('users').doc(user.uid).update({
          'role': 'admin',
          'updatedAt': FieldValue.serverTimestamp(),
        });
        return UserModel(
          id: userModel.id,
          email: userModel.email,
          name: userModel.name,
          role: 'admin',
          createdAt: userModel.createdAt,
          updatedAt: DateTime.now(),
        );
      }
    }
    return userModel;
  }

  Stream<UserModel?> watchCurrentUserProfile() {
    return _auth.authStateChanges().asyncExpand((user) {
      if (user == null) return Stream.value(null);
      final isSuperAdmin = (user.email?.toLowerCase().trim() == UserModel.superAdminEmail);

      return _firestore.collection('users').doc(user.uid).snapshots().map((doc) {
        if (!doc.exists) {
          if (isSuperAdmin) {
            return UserModel(
              id: user.uid,
              email: user.email ?? UserModel.superAdminEmail,
              name: user.displayName ?? 'Super Administrator',
              role: 'superadmin',
              createdAt: DateTime.now(),
            );
          }
          return null;
        }
        final model = UserModel.fromFirestore(doc);
        if (isSuperAdmin && model.role != 'superadmin') {
          return UserModel(
            id: model.id,
            email: model.email,
            name: model.name,
            role: 'superadmin',
            createdAt: model.createdAt,
            updatedAt: model.updatedAt,
          );
        }
        return model;
      });
    });
  }

  Future<UserCredential> signIn(String email, String password) async {
    final cred = await _auth.signInWithEmailAndPassword(
      email: email.trim(),
      password: password,
    );
    if (cred.user != null && cred.user!.email?.trim().toLowerCase() == UserModel.superAdminEmail) {
      try {
        await _firestore.collection('users').doc(cred.user!.uid).set({
          'email': cred.user!.email,
          'role': 'admin',
          'updatedAt': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));
      } catch (_) {}
    }
    return cred;
  }

  Future<UserCredential> signUp(String email, String password, String name) async {
    final cred = await _auth.createUserWithEmailAndPassword(
      email: email.trim(),
      password: password,
    );
    if (cred.user != null) {
      final isSuperAdmin = (email.trim().toLowerCase() == UserModel.superAdminEmail);
      final adminsSnap = await _firestore.collection('users').where('role', isEqualTo: 'admin').limit(1).get();
      final isFirstAdmin = adminsSnap.docs.isEmpty;

      final userModel = UserModel(
        id: cred.user!.uid,
        email: email.trim(),
        name: name.trim().isNotEmpty ? name.trim() : (isSuperAdmin ? 'Super Administrator' : email.trim().split('@').first),
        role: (isFirstAdmin || isSuperAdmin) ? 'admin' : 'staff',
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

  Future<bool> bootstrapAdmin({String? name, String? email, String? password}) async {
    User? user = _auth.currentUser;

    // If user is not yet logged in, attempt login with supplied credentials
    if (user == null && email != null && email.trim().isNotEmpty && password != null && password.isNotEmpty) {
      try {
        final cred = await _auth.signInWithEmailAndPassword(
          email: email.trim(),
          password: password,
        );
        user = cred.user;
      } catch (e) {
        throw Exception('Gagal masuk: Periksa kembali email dan password Anda ($e).');
      }
    }

    if (user == null) {
      throw Exception('Pengguna harus login terlebih dahulu.');
    }

    try {
      // Try Cloud Function callable first
      final callable = _functions.httpsCallable('bootstrapAdmin');
      final result = await callable.call({'name': name ?? ''});
      return result.data['success'] == true;
    } catch (_) {
      // Direct Firestore fallback for bootstrapping initial admin if Cloud Functions are not yet deployed
      final adminsSnap = await _firestore.collection('users').where('role', isEqualTo: 'admin').limit(1).get();
      if (adminsSnap.docs.isNotEmpty && adminsSnap.docs.first.id != user.uid) {
        throw Exception('Administrator sudah ada di sistem. Hubungi admin untuk pemberian hak akses.');
      }

      await _firestore.collection('users').doc(user.uid).set({
        'email': user.email ?? '',
        'name': (name != null && name.trim().isNotEmpty) ? name.trim() : (user.email?.split('@').first ?? 'Administrator'),
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

  Stream<List<UserModel>> watchAllUsers() {
    return _firestore.collection('users').orderBy('createdAt', descending: true).snapshots().map(
      (snap) => snap.docs.map((d) => UserModel.fromFirestore(d)).toList(),
    );
  }

  Future<void> updateUserRole(String userId, String newRole, {String? targetName}) async {
    final currentUser = _auth.currentUser;
    await _firestore.collection('users').doc(userId).update({
      'role': newRole,
      'updatedAt': FieldValue.serverTimestamp(),
    });

    try {
      await _firestore.collection('activity_logs').add({
        'actorId': currentUser?.uid ?? 'system',
        'actorName': currentUser?.email ?? 'Admin',
        'action': 'UPDATE_ROLE',
        'category': 'SECURITY',
        'details': 'Peran pengguna ${targetName ?? userId} diubah menjadi $newRole.',
        'timestamp': FieldValue.serverTimestamp(),
      });
    } catch (_) {}
  }

  /// Memperbarui informasi data diri pengguna saat ini (nama, nomor telepon/WA)
  Future<void> updateProfile({
    required String name,
    String? phone,
  }) async {
    final currentUser = _auth.currentUser;
    if (currentUser == null) {
      throw Exception('Pengguna belum login.');
    }

    final trimmedName = name.trim();
    final trimmedPhone = phone?.trim() ?? '';

    // 1. Update Firebase Auth display name
    try {
      await currentUser.updateDisplayName(trimmedName);
    } catch (_) {}

    // 2. Update Firestore users collection
    await _firestore.collection('users').doc(currentUser.uid).set({
      'name': trimmedName,
      'phone': trimmedPhone,
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));

    // 3. Catat ke Activity Log
    try {
      await _firestore.collection('activity_logs').add({
        'actorId': currentUser.uid,
        'actorName': trimmedName.isNotEmpty ? trimmedName : (currentUser.email ?? 'Pengguna'),
        'action': 'UPDATE_PROFILE',
        'category': 'SECURITY',
        'details': 'Pengguna memperbarui informasi profil data diri (${currentUser.email}).',
        'timestamp': FieldValue.serverTimestamp(),
      });
    } catch (_) {}
  }

  /// Mengubah kata sandi pengguna dengan verifikasi kata sandi lama
  Future<void> changePassword({
    required String currentPassword,
    required String newPassword,
  }) async {
    final user = _auth.currentUser;
    if (user == null || user.email == null) {
      throw Exception('Pengguna belum login.');
    }

    // Re-authenticate
    final cred = EmailAuthProvider.credential(
      email: user.email!,
      password: currentPassword,
    );
    await user.reauthenticateWithCredential(cred);

    // Update password
    await user.updatePassword(newPassword);

    try {
      await _firestore.collection('activity_logs').add({
        'actorId': user.uid,
        'actorName': user.displayName ?? user.email ?? 'Pengguna',
        'action': 'CHANGE_PASSWORD',
        'category': 'SECURITY',
        'details': 'Pengguna berhasil mengubah kata sandi akun.',
        'timestamp': FieldValue.serverTimestamp(),
      });
    } catch (_) {}
  }
}
