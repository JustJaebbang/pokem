import 'package:pokem_app/model/consignment/consignment.dart';
import 'package:pokem_app/model/products/product.dart';
import 'package:pokem_app/repository/products/product_repository.dart';
import 'package:pokem_app/service/consignment/consignment_api_service.dart';

class ConsignmentRepository {
  ConsignmentRepository(this._api, this._products);
  final ConsignmentApiService _api;
  final ProductRepository _products;
  Future<ConsignmentDetail?> get(
    ConsignmentSource source,
    String ownerId,
    String token,
  ) async {
    if ((source.code == null) == (source.inspectCode == null)) {
      throw const ConsignmentException('조회할 대리판매 정보를 확인해주세요.');
    }
    Consignment? item;
    if (source.code != null) {
      item = await _api.detail(source.code!, token);
      if (item.code != source.code) {
        throw const ConsignmentException('대리판매 등록번호가 일치하지 않습니다.');
      }
    } else {
      final rows = await _api.list(token);
      if (rows.any((r) => r.ownerId != ownerId)) {
        throw const ConsignmentException('대리판매 소유자를 확인하지 못했습니다.');
      }
      final matches = rows
          .where((r) => r.inspectCode == source.inspectCode)
          .toList();
      if (matches.isEmpty) return null;
      if (matches.length != 1) {
        throw const ConsignmentException('대리판매 등록 정보를 확인해주세요.');
      }
      item = await _api.detail(matches.single.code, token);
      if (item.code != matches.single.code ||
          item.inspectCode != source.inspectCode) {
        throw const ConsignmentException('검수번호와 대리판매 정보가 일치하지 않습니다.');
      }
    }
    if (item.ownerId != ownerId) {
      throw const ConsignmentException('대리판매 소유자를 확인하지 못했습니다.');
    }
    try {
      final product = await _products.getProduct(item.productCode);
      if (product.code != item.productCode ||
          product.sellerId != ownerId ||
          product.saleType != 'consign') {
        throw const ProductException('연결된 상품 정보를 확인하지 못했습니다.');
      }
      return ConsignmentDetail(item, product: product);
    } on ProductException catch (e) {
      if (e.statusCode == 401) {
        throw ConsignmentException(e.message, status: 401);
      }
      return ConsignmentDetail(item, productError: e.message);
    } catch (_) {
      return ConsignmentDetail(item, productError: '상품 정보를 불러오지 못했습니다.');
    }
  }
}
