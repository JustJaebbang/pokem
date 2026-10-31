class ProductEditInput {
  const ProductEditInput({
    required this.title,
    required this.description,
    required this.price,
  });
  final String title, description, price;
}

class ProductEditDraft {
  const ProductEditDraft({
    required this.title,
    required this.description,
    required this.price,
    required this.image,
  });
  final String title, description, image;
  final int price;
  Map<String, Object> toJson() => {
    'sell_product_title': title,
    'sell_product_contents': description,
    'sell_product_sell_price': price,
    'sell_product_image': image,
  };
}
