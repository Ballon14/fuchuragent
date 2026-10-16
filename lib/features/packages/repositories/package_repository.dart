import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/package_model.dart';

class PackageRepository {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  CollectionReference get _pkgRef => _firestore.collection('vps_packages');

  Stream<List<VpsPackageModel>> watchPackages() {
    return _pkgRef.snapshots().map((snap) {
      if (snap.docs.isEmpty) {
        return VpsPackageModel.defaultCatalog;
      }
      return snap.docs.map((d) => VpsPackageModel.fromFirestore(d)).toList();
    });
  }

  Future<List<VpsPackageModel>> getPackages() async {
    final snap = await _pkgRef.get();
    if (snap.docs.isEmpty) {
      await seedDefaultPackages();
      return VpsPackageModel.defaultCatalog;
    }
    return snap.docs.map((d) => VpsPackageModel.fromFirestore(d)).toList();
  }

  Future<void> seedDefaultPackages() async {
    final batch = _firestore.batch();
    for (final pkg in VpsPackageModel.defaultCatalog) {
      final docRef = _pkgRef.doc(pkg.id);
      batch.set(docRef, pkg.toMap(), SetOptions(merge: true));
    }
    await batch.commit();
  }

  Future<void> savePackage(VpsPackageModel package) async {
    final docRef = _pkgRef.doc(package.id.isNotEmpty ? package.id : null);
    await docRef.set(package.toMap(), SetOptions(merge: true));

    await _firestore.collection('activity_logs').add({
      'actorId': _auth.currentUser?.uid ?? 'system',
      'actorName': _auth.currentUser?.email ?? 'Admin',
      'action': 'SAVE_PACKAGE',
      'category': 'SERVICES',
      'details': 'Menyimpan konfigurasi paket VPS: ${package.name} (Rp${package.basePrice}/bln)',
      'targetId': docRef.id,
      'timestamp': FieldValue.serverTimestamp(),
    });
  }
}
