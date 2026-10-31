import 'package:pokem_app/model/delivery/delivery.dart';
import 'package:pokem_app/service/delivery/delivery_api_service.dart';

class DeliveryRepository {
  DeliveryRepository(this._api);
  final DeliveryApiService _api;
  Future<Delivery?> find(
    DeliverySource source,
    String userId,
    String token,
  ) async {
    if ((source.purchaseCode == null) == (source.returnNo == null)) {
      throw const DeliveryException('배송을 조회할 구매 또는 반환 정보를 확인해주세요.');
    }
    for (var offset = 0; ; offset += 100) {
      final page = await _api.list(token, offset);
      if (page.any((row) => row.userId != userId)) {
        throw const DeliveryException('배송 정보의 사용자 확인에 실패했습니다.');
      }
      for (final item in page) {
        if (item.matches(source)) {
          final latest = await _api.detail(item.number, token);
          if (latest.userId != userId || !latest.matches(source)) {
            throw const DeliveryException('요청한 내역과 배송 정보가 일치하지 않습니다.');
          }
          return latest;
        }
      }
      if (page.length < 100) return null;
    }
  }
}
