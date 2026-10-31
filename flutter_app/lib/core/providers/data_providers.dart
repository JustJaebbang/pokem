import 'package:pokem_app/repository/products/product_edit_repository.dart';
import 'package:pokem_app/service/products/product_edit_api_service.dart';
import 'package:pokem_app/repository/review/review_repository.dart';
import 'package:pokem_app/service/review/review_api_service.dart';
import 'package:pokem_app/repository/purchase/seller_cancel_repository.dart';
import 'package:pokem_app/repository/purchase/purchase_cancel_repository.dart';
import 'package:pokem_app/service/purchase/purchase_api_service.dart';
import 'package:pokem_app/repository/inspection/return_repository.dart';
import 'package:pokem_app/service/inspection/return_api_service.dart';
import 'package:pokem_app/repository/inspection/inspection_fee_repository.dart';
import 'package:pokem_app/service/inspection/inspection_fee_api_service.dart';
import 'package:pokem_app/repository/inspection/inspection_repository.dart';
import 'package:pokem_app/service/inspection/inspection_api_service.dart';
import 'package:pokem_app/repository/profile/profile_repository.dart';
import 'package:pokem_app/repository/sales/sales_repository.dart';
import 'package:pokem_app/service/sales/sales_api_service.dart';
import 'package:pokem_app/repository/wallet/wallet_repository.dart';
import 'package:pokem_app/service/wallet/wallet_api_service.dart';
import 'package:pokem_app/repository/purchase/purchase_repository.dart';
import 'package:pokem_app/service/chat/chat_api_service.dart';
import 'package:pokem_app/service/chat/chat_socket_service.dart';
import 'package:pokem_app/repository/chat/chat_repository.dart';
import 'package:pokem_app/service/wishlist/wishlist_api_service.dart';
import 'package:pokem_app/repository/wishlist/wishlist_repository.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import 'package:pokem_app/core/config/api_config.dart';
import 'package:pokem_app/service/auth/auth_api_service.dart';
import 'package:pokem_app/repository/auth/auth_repository.dart';
import 'package:pokem_app/core/storage/session_storage.dart';
import 'package:pokem_app/service/products/product_api_service.dart';
import 'package:pokem_app/repository/products/product_repository.dart';
import 'package:pokem_app/service/products/product_photo_picker.dart';
import 'package:pokem_app/service/products/product_publish_api_service.dart';
import 'package:pokem_app/repository/products/product_publish_repository.dart';

final authApiServiceProvider = Provider<AuthApiService>((ref) {
  final client = http.Client();
  ref.onDispose(client.close);
  return AuthApiService(client, baseUrl: ApiConfig.baseUrl);
});

final authRepositoryProvider = Provider<AuthRepository>(
  (ref) => AuthRepository(
    ref.watch(authApiServiceProvider),
    ref.watch(sessionStorageProvider),
  ),
);

final sessionStorageProvider = Provider<SessionStorage>(
  (ref) => SecureSessionStorage(),
);

final productApiServiceProvider = Provider<ProductApiService>((ref) {
  final client = http.Client();
  ref.onDispose(client.close);
  return ProductApiService(client, baseUrl: ApiConfig.baseUrl);
});

final productRepositoryProvider = Provider<ProductRepository>(
  (ref) => ProductRepository(ref.watch(productApiServiceProvider)),
);

final productPhotoPickerProvider = Provider<ProductPhotoPicker>(
  (ref) => ProductPhotoPicker(),
);

final productPublishApiServiceProvider = Provider<ProductPublishApiService>((
  ref,
) {
  final client = http.Client();
  ref.onDispose(client.close);
  return ProductPublishApiService(client, baseUrl: ApiConfig.baseUrl);
});

final productPublishRepositoryProvider = Provider<ProductPublishRepository>(
  (ref) =>
      ProductPublishRepository(ref.watch(productPublishApiServiceProvider)),
);

final wishlistApiServiceProvider = Provider<WishlistApiService>((ref) {
  final client = http.Client();
  ref.onDispose(client.close);
  return WishlistApiService(client, baseUrl: ApiConfig.baseUrl);
});
final wishlistRepositoryProvider = Provider<WishlistRepository>(
  (ref) => WishlistRepository(
    ref.watch(wishlistApiServiceProvider),
    ref.watch(productRepositoryProvider),
  ),
);

final chatRepositoryProvider = Provider<ChatRepository>((ref) {
  final client = http.Client();
  ref.onDispose(client.close);
  return ChatRepository(
    ChatApiService(client, baseUrl: ApiConfig.baseUrl),
    ChatSocketService(baseUrl: ApiConfig.baseUrl),
  );
});

final purchaseRepositoryProvider = Provider<PurchaseRepository>((ref) {
  final client = http.Client();
  ref.onDispose(client.close);
  return PurchaseRepository(
    PurchaseApiService(client, baseUrl: ApiConfig.baseUrl),
    ref.watch(productRepositoryProvider),
  );
});

final walletRepositoryProvider = Provider<WalletRepository>((ref) {
  final client = http.Client();
  ref.onDispose(client.close);
  return WalletRepository(WalletApiService(client, baseUrl: ApiConfig.baseUrl));
});

final salesRepositoryProvider = Provider<SalesRepository>((ref) {
  final client = http.Client();
  ref.onDispose(client.close);
  return SalesRepository(SalesApiService(client, baseUrl: ApiConfig.baseUrl));
});

final profileRepositoryProvider = Provider<ProfileRepository>(
  (ref) => ProfileRepository(ref.watch(authApiServiceProvider)),
);

final inspectionRepositoryProvider = Provider<InspectionRepository>((ref) {
  final client = http.Client();
  ref.onDispose(client.close);
  return InspectionRepository(
    InspectionApiService(client, baseUrl: ApiConfig.baseUrl),
  );
});

final inspectionFeeRepositoryProvider = Provider<InspectionFeeRepository>((
  ref,
) {
  final client = http.Client();
  ref.onDispose(client.close);
  return InspectionFeeRepository(
    InspectionFeeApiService(client, baseUrl: ApiConfig.baseUrl),
  );
});

final returnRepositoryProvider = Provider<ReturnRepository>((ref) {
  final client = http.Client();
  ref.onDispose(client.close);
  return ReturnRepository(ReturnApiService(client, baseUrl: ApiConfig.baseUrl));
});

final purchaseCancelRepositoryProvider = Provider<PurchaseCancelRepository>((
  ref,
) {
  final client = http.Client();
  ref.onDispose(client.close);
  return PurchaseCancelRepository(
    PurchaseApiService(client, baseUrl: ApiConfig.baseUrl),
  );
});

final sellerCancelRepositoryProvider = Provider<SellerCancelRepository>((ref) {
  final client = http.Client();
  ref.onDispose(client.close);
  return SellerCancelRepository(
    PurchaseApiService(client, baseUrl: ApiConfig.baseUrl),
  );
});

final reviewRepositoryProvider = Provider<ReviewRepository>((ref) {
  final client = http.Client();
  ref.onDispose(client.close);
  return ReviewRepository(
    ReviewApiService(client, baseUrl: ApiConfig.baseUrl),
    PurchaseApiService(client, baseUrl: ApiConfig.baseUrl),
  );
});

final productEditRepositoryProvider = Provider<ProductEditRepository>((ref) {
  final client = http.Client();
  ref.onDispose(client.close);
  return ProductEditRepository(
    ProductEditApiService(client, baseUrl: ApiConfig.baseUrl),
    ref.watch(productRepositoryProvider),
  );
});
