class Product {
  const Product({
    required this.code,
    required this.serialCode,
    required this.title,
    required this.image,
    required this.description,
    required this.price,
    required this.grade,
    required this.status,
  });
  final String code;
  final String serialCode;
  final String title;
  final String image;
  final String description;
  final int price;
  final String grade;
  final String status;
  bool get isForSale => status == '판매중';

  factory Product.fromJson(Map<String, dynamic> json) => Product(
    code: json['sell_product_code'] as String,
    serialCode: json['sell_product_serial_code'] as String,
    title: json['sell_product_title'] as String,
    image: json['sell_product_image'] as String,
    description: json['sell_product_contents'] as String,
    price: json['sell_product_sell_price'] as int,
    grade: json['sell_product_grade'] as String,
    status: json['sell_product_sell_status'] as String,
  );
}

class ProductException implements Exception {
  const ProductException(this.message, {this.statusCode});
  final String message;
  final int? statusCode;
  @override
  String toString() => message;
}
