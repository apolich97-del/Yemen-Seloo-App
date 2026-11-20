import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:get/get.dart';

import 'catalog_models.dart';

/// كتالوج يمن سيلو — قراءة عامة، كتابة للمسوّق والمدير.
class CatalogRepository extends GetxService {
  final _db = FirebaseFirestore.instance;

  Stream<List<CatalogItem>> activeItems() => _db
      .collection('catalog')
      .where('active', isEqualTo: true)
      .snapshots()
      .map((s) => s.docs
          .map((d) => CatalogItem.fromDoc(d.id, d.data()))
          .toList()
        ..sort((a, b) => (b.createdAt ?? DateTime(2000))
            .compareTo(a.createdAt ?? DateTime(2000))));

  Stream<List<CatalogItem>> allItems() => _db
      .collection('catalog')
      .snapshots()
      .map((s) => s.docs
          .map((d) => CatalogItem.fromDoc(d.id, d.data()))
          .toList()
        ..sort((a, b) => (b.createdAt ?? DateTime(2000))
            .compareTo(a.createdAt ?? DateTime(2000))));

  Future<String> create(CatalogItem item) async {
    final ref = await _db.collection('catalog').add(item.toMap());
    return ref.id;
  }

  Future<void> update(CatalogItem item) =>
      _db.collection('catalog').doc(item.id).set(item.toMap(), SetOptions(merge: true));

  Future<void> setActive(String id, bool active) =>
      _db.collection('catalog').doc(id).set({'active': active}, SetOptions(merge: true));

  Future<void> remove(String id) => _db.collection('catalog').doc(id).delete();
}
