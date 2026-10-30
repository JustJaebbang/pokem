import 'package:pokem_app/model/products/product.dart';

class ProductDetailState {
  const ProductDetailState({
    required this.product,
    required this.canChat,
    required this.canBuy,
  });
  final Product product;
  final bool canChat, canBuy;
}
