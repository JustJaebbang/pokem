import 'package:flutter/material.dart';

import 'market_product.dart';
import 'purchase_item.dart';

class ProductDetailPage extends StatefulWidget {
  const ProductDetailPage(
      {super.key,
      required this.product,
      required this.token,
      this.canTrade = true,
      required this.isWishlisted,
      required this.onToggleWishlist,
      this.onReturnedFromPurchase});

  final MarketProduct product;
  final String token;
  final bool canTrade;
  final bool isWishlisted;
  final VoidCallback onToggleWishlist;
  final Future<void> Function()? onReturnedFromPurchase;

  @override
  State<ProductDetailPage> createState() => _ProductDetailPageState();
}

class _ProductDetailPageState extends State<ProductDetailPage> {
  late bool _isWishlisted;

  @override
  void initState() {
    super.initState();
    _isWishlisted = widget.isWishlisted;
  }

  void _toggleWishlist() {
    widget.onToggleWishlist();
    setState(() => _isWishlisted = !_isWishlisted);
  }

  @override
  Widget build(BuildContext context) {
    final isForSale = widget.product.status == '판매중';
    return Scaffold(
      appBar: AppBar(title: const Text('상품 상세')),
      body: ListView(
        children: [
          AspectRatio(
              aspectRatio: 1,
              child: ProductImageView(source: widget.product.image)),
          Padding(
            padding: const EdgeInsets.all(20),
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(widget.product.title,
                  style: const TextStyle(
                      fontSize: 22, fontWeight: FontWeight.w800)),
              if (widget.product.brand.isNotEmpty ||
                  widget.product.category.isNotEmpty) ...[
                const SizedBox(height: 11),
                Wrap(spacing: 8, runSpacing: 6, children: [
                  if (widget.product.brand.isNotEmpty)
                    _MetadataChip(label: '브랜드', value: widget.product.brand),
                  if (widget.product.category.isNotEmpty)
                    _MetadataChip(
                        label: '카테고리', value: widget.product.category),
                ]),
              ],
              const SizedBox(height: 10),
              Text('${formatMarketPrice(widget.product.price)}원',
                  style: const TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.w800,
                      color: Color(0xFF5144C8))),
              const Divider(height: 30),
              _DetailRow(label: '상품 코드', value: widget.product.code),
              if (widget.product.grade.isNotEmpty)
                _DetailRow(label: '등급', value: widget.product.grade),
              if (widget.product.status.isNotEmpty)
                _DetailRow(label: '판매 상태', value: widget.product.status),
              const SizedBox(height: 18),
              const Text('상품 설명',
                  style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
              if (widget.product.contents.isNotEmpty &&
                  widget.product.contents.toLowerCase() != 'string') ...[
                const SizedBox(height: 8),
                Text(widget.product.contents,
                    style:
                        const TextStyle(height: 1.5, color: Color(0xFF5F6676))),
              ],
            ]),
          ),
        ],
      ),
      bottomNavigationBar: widget.canTrade
          ? SafeArea(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 10, 16, 12),
                child: Row(children: [
                  Material(
                    color: _isWishlisted
                        ? const Color(0xFFFFE8F0)
                        : const Color(0xFFF0F1F6),
                    borderRadius: BorderRadius.circular(14),
                    child: IconButton(
                      tooltip: _isWishlisted ? '관심상품 해제' : '관심상품 추가',
                      onPressed: _toggleWishlist,
                      icon: Icon(
                          _isWishlisted
                              ? Icons.favorite_rounded
                              : Icons.favorite_border_rounded,
                          color: _isWishlisted
                              ? const Color(0xFFE84D83)
                              : const Color(0xFF596174)),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: SizedBox(
                      height: 50,
                      child: FilledButton.icon(
                        onPressed: isForSale
                            ? () async {
                                await Navigator.of(context).push<void>(
                                  MaterialPageRoute<void>(
                                    builder: (_) => PurchaseItemPage(
                                        token: widget.token,
                                        product: widget.product),
                                  ),
                                );
                                await widget.onReturnedFromPurchase?.call();
                              }
                            : null,
                        style: FilledButton.styleFrom(
                            backgroundColor: const Color(0xFF6658E8),
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(14))),
                        icon: const Icon(Icons.shopping_bag_outlined),
                        label: Text(isForSale ? '구매하기' : '판매 중이 아닙니다',
                            style: TextStyle(fontWeight: FontWeight.w700)),
                      ),
                    ),
                  ),
                ]),
              ),
            )
          : null,
    );
  }
}

class _MetadataChip extends StatelessWidget {
  const _MetadataChip({required this.label, required this.value});
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) => Chip(
        label: Text('$label · $value',
            style: const TextStyle(fontSize: 12, color: Color(0xFF5144C8))),
        side: BorderSide.none,
        backgroundColor: const Color(0xFFECEAFF),
        visualDensity: VisualDensity.compact,
      );
}

class _DetailRow extends StatelessWidget {
  const _DetailRow({required this.label, required this.value});
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: Row(children: [
          SizedBox(
              width: 90,
              child: Text(label,
                  style: const TextStyle(color: Color(0xFF858B9A)))),
          Expanded(
              child: Text(value,
                  style: const TextStyle(fontWeight: FontWeight.w600)))
        ]),
      );
}
