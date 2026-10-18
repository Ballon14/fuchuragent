import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/package_model.dart';

class PackageRepository {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  CollectionReference get _pkgRef => _firestore.collection('vps_packages');

  Stream<List<VpsPackageModel>> watchPackages() {
    return _pkgRef.snapshots().map((snap) {
      List<VpsPackageModel> list;
      if (snap.docs.isEmpty) {
        list = List<VpsPackageModel>.from(VpsPackageModel.defaultCatalog);
      } else {
        final existing = snap.docs.map((d) => VpsPackageModel.fromFirestore(d)).toList();
        final existingNames = existing.map((p) => p.name.toLowerCase()).toSet();
        list = List<VpsPackageModel>.from(existing);
        for (final def in VpsPackageModel.defaultCatalog) {
          if (!existingNames.contains(def.name.toLowerCase())) {
            list.add(def);
          }
        }
      }
      for (int i = 0; i < list.length; i++) {
        if (list[i].name.toLowerCase() == 'basic' && list[i].basePrice == 80000) {
          list[i] = list[i].copyWith(basePrice: 76000);
        }
      }
      list.sort((a, b) => a.basePrice.compareTo(b.basePrice));
      return list;
    });
  }

  Future<List<VpsPackageModel>> getPackages() async {
    final snap = await _pkgRef.get();
    List<VpsPackageModel> list;
    if (snap.docs.isEmpty) {
      await seedDefaultPackages();
      list = List<VpsPackageModel>.from(VpsPackageModel.defaultCatalog);
    } else {
      final existing = snap.docs.map((d) => VpsPackageModel.fromFirestore(d)).toList();
      final existingNames = existing.map((p) => p.name.toLowerCase()).toSet();
      list = List<VpsPackageModel>.from(existing);
      for (final def in VpsPackageModel.defaultCatalog) {
        if (!existingNames.contains(def.name.toLowerCase())) {
          list.add(def);
        }
      }
    }
    for (int i = 0; i < list.length; i++) {
      if (list[i].name.toLowerCase() == 'basic' && list[i].basePrice == 80000) {
        list[i] = list[i].copyWith(basePrice: 76000);
      }
    }
    list.sort((a, b) => a.basePrice.compareTo(b.basePrice));
    return list;
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
