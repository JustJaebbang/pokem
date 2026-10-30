import 'dart:async';

import 'package:pokem_app/model/products/product.dart';
import 'package:pokem_app/model/wishlist/wishlist_record.dart';
import 'package:pokem_app/repository/wishlist/wishlist_repository.dart';

class MemoryWishlistRepository implements WishlistRepository {
  MemoryWishlistRepository({
    this.allProducts = const [],
    Set<String>? initialCodes,
  }) : codes = {...?initialCodes};
  final List<Product> allProducts;
  final Set<String> codes;
  int loads = 0, changes = 0;
  Object? loadError, changeError;
  Completer<void>? changeGate, loadGate;
  @override
  Future<WishlistSnapshot> getSnapshot(String userId, String token) async {
    loads++;
    if (loadGate != null) await loadGate!.future;
    if (loadError != null) throw loadError!;
    return WishlistSnapshot(
      codes: {...codes},
      products: allProducts.where((p) => codes.contains(p.code)).toList(),
    );
  }

  @override
  Future<WishlistRecord> setWished(
    String userId,
    String code,
    bool wished,
    String token,
  ) async {
    changes++;
    if (changeGate != null) await changeGate!.future;
    if (changeError != null) throw changeError!;
    if (wished) {
      codes.add(code);
    } else {
      codes.remove(code);
    }
    return WishlistRecord(code: code, userId: userId, isWished: wished);
  }
}
