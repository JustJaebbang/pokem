enum ProductSort {
  newest('newest', '최신순'),
  priceAsc('price_asc', '낮은 가격순'),
  priceDesc('price_desc', '높은 가격순');

  const ProductSort(this.value, this.label);
  final String value, label;
}

typedef ProductSearchSpec = ({String query, ProductSort sort});

class ProductClassification {
  const ProductClassification({this.category, this.brand});
  final String? category, brand;
  factory ProductClassification.fromJson(Map<String, dynamic> json) =>
      ProductClassification(
        category: json['category'] as String?,
        brand: json['brand'] as String?,
      );
}
