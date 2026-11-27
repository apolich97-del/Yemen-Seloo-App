import 'dart:async';
import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:get/get.dart';
import 'package:get_storage/get_storage.dart';

import 'catalog_models.dart';

/// كتالوج يمن سيلو — قراءة عامة مع تخزين مؤقت محلي فوري، كتابة للمسوّق والمدير.
class CatalogRepository extends GetxService {
  final _db = FirebaseFirestore.instance;
  final _box = GetStorage();

  static const _kActiveCacheKey = 'seloo_catalog_active_cache_v1';
  static const _kAllCacheKey = 'seloo_catalog_all_cache_v1';

  List<CatalogItem> _readCache(String key) {
    try {
      final raw = _box.read(key);
      if (raw is! String || raw.isEmpty) return const <CatalogItem>[];
      final decoded = jsonDecode(raw);
      if (decoded is! List) return const <CatalogItem>[];
      return decoded
          .whereType<Map>()
          .map((m) {
            final map = Map<String, dynamic>.from(m);
            final id = (map['id'] ?? '').toString();
            final createdMs = map['createdAtMs'];
            final item = CatalogItem.fromDoc(id, map);
            if (item.createdAt == null && createdMs is num) {
              return CatalogItem(
                id: item.id,
                title: item.title,
                goodsId: item.goodsId,
                sourceUrl: item.sourceUrl,
                imageUrl: item.imageUrl,
                category: item.category,
                colors: item.colors,
                sizes: item.sizes,
                basePriceSar: item.basePriceSar,
                marginSar: item.marginSar,
                region: item.region,
                badge: item.badge,
                active: item.active,
                nonRefundable: item.nonRefundable,
                nonRefundableReason: item.nonRefundableReason,
                createdAt: DateTime.fromMillisecondsSinceEpoch(createdMs.toInt()),
              );
            }
            return item;
          })
          .toList();
    } catch (_) {
      return const <CatalogItem>[];
    }
  }

  void _writeCache(String key, List<CatalogItem> items) {
    try {
      final encoded = jsonEncode(items.map((it) {
        return <String, dynamic>{
          'id': it.id,
          'title': it.title,
          'goodsId': it.goodsId,
          'sourceUrl': it.sourceUrl,
          'imageUrl': it.imageUrl,
          'category': it.category,
          'colors': it.colors,
          'sizes': it.sizes,
          'basePriceSar': it.basePriceSar,
          'marginSar': it.marginSar,
          'region': it.region,
          'badge': it.badge,
          'active': it.active,
          'nonRefundable': it.nonRefundable,
          'nonRefundableReason': it.nonRefundableReason,
          if (it.createdAt != null)
            'createdAtMs': it.createdAt!.millisecondsSinceEpoch,
        };
      }).toList());
      _box.write(key, encoded);
    } catch (_) {}
  }

  Stream<List<CatalogItem>> _cachedStream({
    required Query<Map<String, dynamic>> query,
    required String cacheKey,
  }) {
    late final StreamController<List<CatalogItem>> ctrl;
    StreamSubscription<QuerySnapshot<Map<String, dynamic>>>? sub;
    ctrl = StreamController<List<CatalogItem>>(
      onListen: () {
        final cached = _readCache(cacheKey);
        if (cached.isNotEmpty && !ctrl.isClosed) {
          ctrl.add(cached);
        }
        sub = query.snapshots().listen(
          (snap) {
            final list = snap.docs
                .map((d) => CatalogItem.fromDoc(d.id, d.data()))
                .toList()
              ..sort((a, b) => (b.createdAt ?? DateTime(2000))
                  .compareTo(a.createdAt ?? DateTime(2000)));
            _writeCache(cacheKey, list);
            if (!ctrl.isClosed) ctrl.add(list);
          },
          onError: (Object err, StackTrace st) {
            if (_readCache(cacheKey).isEmpty && !ctrl.isClosed) {
              ctrl.addError(err, st);
            }
          },
        );
      },
      onCancel: () => sub?.cancel(),
    );
    return ctrl.stream;
  }

  Stream<List<CatalogItem>> activeItems() => _cachedStream(
        query: _db.collection('catalog').where('active', isEqualTo: true),
        cacheKey: _kActiveCacheKey,
      );

  Stream<List<CatalogItem>> allItems() => _cachedStream(
        query: _db.collection('catalog'),
        cacheKey: _kAllCacheKey,
      );

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
