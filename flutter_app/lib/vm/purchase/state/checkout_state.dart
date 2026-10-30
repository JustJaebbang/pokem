import 'package:pokem_app/repository/purchase/purchase_repository.dart';
import 'package:pokem_app/model/purchase/purchase.dart';

class CheckoutState {
  const CheckoutState({
    this.data,
    this.loading = true,
    this.paying = false,
    this.agreed = false,
    this.uncertain = false,
    this.error,
    this.purchase,
  });
  final CheckoutData? data;
  final bool loading;
  final bool paying;
  final bool agreed;
  final bool uncertain;
  final String? error;
  final Purchase? purchase;
  bool get canPay =>
      !loading &&
      !paying &&
      !uncertain &&
      purchase == null &&
      agreed &&
      data != null &&
      data!.product.isForSale &&
      data!.buyer.balance >= data!.product.price;
}
