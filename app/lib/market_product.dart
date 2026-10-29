import 'dart:convert';

import 'package:flutter/material.dart';

import 'api_config.dart';

class MarketProduct {
  const MarketProduct({
    required this.code,
    required this.serialCode,
    required this.title,
    required this.image,
    required this.contents,
    required this.price,
    required this.grade,
    required this.status,
    required this.brand,
    required this.category,
  });

  final String code;
  final String serialCode;
  final String title;
  final String image;
  final String contents;
  final int price;
  final String grade;
  final String status;
  final String brand;
  final String category;

  factory MarketProduct.fromJson(Map<String, dynamic> json) {
    final serialCode = (json['sell_product_serial_code'] ?? '').toString();
    return MarketProduct(
      code: (json['sell_product_code'] ?? '').toString(),
      serialCode: serialCode,
      title: _clean(json['sell_product_title']).isEmpty
          ? '상품'
          : _clean(json['sell_product_title']),
      image: _clean(json['sell_product_image']),
      contents: _clean(json['sell_product_contents']),
      price: (json['sell_product_sell_price'] as num?)?.toInt() ??
          int.tryParse('${json['sell_product_sell_price']}') ??
          0,
      grade: _clean(json['sell_product_grade']),
      status: _clean(json['sell_product_sell_status']),
      brand: '',
      category: serialCode.replaceAll('_', ' · '),
    );
  }
}

String _clean(Object? value) {
  final text = (value ?? '').toString().trim();
  return text.toLowerCase() == 'string' ? '' : text;
}

String formatMarketPrice(int price) => price.toString().replaceAllMapped(
    RegExp(r'(\d)(?=(\d{3})+(?!\d))'), (match) => '${match[1]},');

class ProductImageView extends StatelessWidget {
  const ProductImageView(
      {super.key, required this.source, this.fit = BoxFit.cover});

  final String source;
  final BoxFit fit;

  @override
  Widget build(BuildContext context) {
    final value = source.trim();
    if (value.isEmpty || value.toLowerCase() == 'string') {
      return _placeholder();
    }
    if (value.startsWith('data:image/')) {
      final comma = value.indexOf(',');
      if (comma > 0) {
        try {
          return Image.memory(base64Decode(value.substring(comma + 1)),
              fit: fit, errorBuilder: (_, __, ___) => _placeholder());
        } catch (_) {
          return _placeholder();
        }
      }
    }
    final uri = Uri.tryParse(value);
    final apiUri = Uri.tryParse(apiBaseUrl);
    final imagePath = (uri?.path ?? value).replaceFirst(RegExp(r'^/+'), '');
    final belongsToApi = uri == null ||
        !uri.hasAuthority ||
        (apiUri != null &&
            uri.scheme == apiUri.scheme &&
            uri.host == apiUri.host &&
            uri.port == apiUri.port);
    if (belongsToApi && imagePath.startsWith('uploads/products/')) {
      // Older records point to a server upload path that is not served by this API.
      // Don't issue repeated requests that can only return 404.
      return _placeholder();
    }
    final url = uri != null && (uri.scheme == 'http' || uri.scheme == 'https')
        ? value
        : value.isEmpty
            ? null
            : Uri.parse(apiBaseUrl).resolve(value).toString();
    if (url == null) return _placeholder();
    return Image.network(url,
        fit: fit, errorBuilder: (_, __, ___) => _placeholder());
  }

  Widget _placeholder() => Container(
        color: const Color(0xFFF0F1F6),
        alignment: Alignment.center,
        child: const Icon(Icons.image_outlined,
            size: 42, color: Color(0xFFAFB4C1)),
      );
}

class ProductCard extends StatelessWidget {
  const ProductCard(
      {super.key,
      required this.product,
      required this.isWishlisted,
      required this.onFavorite,
      required this.onTap});

  final MarketProduct product;
  final bool isWishlisted;
  final VoidCallback onFavorite;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Material(
        color: Colors.white,
        borderRadius: BorderRadius.circular(17),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Stack(children: [
            Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Expanded(
                  child: SizedBox.expand(
                      child: ProductImageView(source: product.image))),
              Padding(
                padding: const EdgeInsets.fromLTRB(11, 9, 11, 12),
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(product.title,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                              fontWeight: FontWeight.w600, fontSize: 14)),
                      const SizedBox(height: 6),
                      Text('${formatMarketPrice(product.price)}원',
                          style: const TextStyle(
                              fontWeight: FontWeight.w800,
                              fontSize: 16,
                              color: Color(0xFF20283B))),
                      if (product.status.isNotEmpty) ...[
                        const SizedBox(height: 4),
                        Text(product.status,
                            style: const TextStyle(
                                fontSize: 11, color: Color(0xFF858B9A)))
                      ],
                    ]),
              ),
            ]),
            Positioned(
              top: 7,
              right: 7,
              child: Material(
                color: Colors.white.withValues(alpha: 0.92),
                shape: const CircleBorder(),
                child: IconButton(
                  visualDensity: VisualDensity.compact,
                  tooltip: isWishlisted ? '관심상품 해제' : '관심상품 추가',
                  onPressed: onFavorite,
                  icon: Icon(
                      isWishlisted
                          ? Icons.favorite_rounded
                          : Icons.favorite_border_rounded,
                      color: isWishlisted
                          ? const Color(0xFFE84D83)
                          : const Color(0xFF596174),
                      size: 21),
                ),
              ),
            ),
          ]),
        ),
      );
}
