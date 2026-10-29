import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

import 'api_config.dart';

class ReviewPage extends StatefulWidget {
  const ReviewPage({
    super.key,
    required this.token,
    required this.userId,
  });

  final String token;
  final String userId;

  @override
  State<ReviewPage> createState() => _ReviewPageState();
}

class _ReviewPageState extends State<ReviewPage> {
  late Future<_ReviewData> _data;

  @override
  void initState() {
    super.initState();
    _data = _loadData();
  }

  Future<_ReviewData> _loadData() async {
    final headers = {'Authorization': 'Bearer ${widget.token}'};
    final responses = await Future.wait([
      http.get(Uri.parse('$apiBaseUrl/purchase_item'), headers: headers),
      http.get(Uri.parse('$apiBaseUrl/review'), headers: headers),
    ]).timeout(const Duration(seconds: 15));
    for (final response in responses) {
      if (response.statusCode != 200) throw Exception(_error(response));
    }
    final purchasesJson = jsonDecode(utf8.decode(responses[0].bodyBytes));
    final reviewsJson = jsonDecode(utf8.decode(responses[1].bodyBytes));
    if (purchasesJson is! List || reviewsJson is! List) {
      throw const FormatException('리뷰 정보를 불러오지 못했습니다.');
    }
    final purchases = purchasesJson
        .map((item) => Map<String, dynamic>.from(item as Map))
        .toList();
    final reviews = reviewsJson
        .map((item) => Map<String, dynamic>.from(item as Map))
        .where((item) => item['user_user_id']?.toString() == widget.userId)
        .toList();
    final reviewedPurchaseCodes = reviews
        .map((item) => item['purchase_item_purchase_item_code']?.toString())
        .whereType<String>()
        .toSet();
    return _ReviewData(
      eligiblePurchases: purchases.where((purchase) {
        final code = purchase['purchase_item_code']?.toString() ?? '';
        return _isConfirmed(purchase['purchase_item_status']?.toString()) &&
            !reviewedPurchaseCodes.contains(code);
      }).toList(),
      reviews: reviews,
    );
  }

  Future<void> _refresh() async {
    final next = _loadData();
    setState(() => _data = next);
    try {
      await next;
    } catch (_) {}
  }

  Future<void> _writeReview(Map<String, dynamic> purchase) async {
    final result = await showDialog<_ReviewDraft>(
      context: context,
      builder: (context) => const _ReviewFormDialog(),
    );
    if (result == null || !mounted) return;
    final purchaseCode = purchase['purchase_item_code']?.toString() ?? '';
    try {
      final response = await http
          .post(
            Uri.parse('$apiBaseUrl/review'),
            headers: {
              'Authorization': 'Bearer ${widget.token}',
              'Content-Type': 'application/json',
            },
            body: jsonEncode({
              'purchase_item_purchase_item_code': purchaseCode,
              'review_rating': result.rating,
              'review_contents': result.contents,
            }),
          )
          .timeout(const Duration(seconds: 15));
      final body = _decode(response);
      if (response.statusCode != 200 && response.statusCode != 201) {
        throw Exception(_error(response, body));
      }
      if (!mounted) return;
      final reviewCode = body['review_code']?.toString() ?? '';
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(reviewCode.isEmpty ? '리뷰가 등록되었습니다.' : '리뷰 등록 완료 · 코드 $reviewCode')),
      );
      await _refresh();
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(error.toString().replaceFirst('Exception: ', ''))),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: const Text('구매 리뷰')),
        body: FutureBuilder<_ReviewData>(
          future: _data,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting &&
                !snapshot.hasData) {
              return const Center(child: CircularProgressIndicator());
            }
            if (snapshot.hasError) {
              return Center(
                child: Column(mainAxisSize: MainAxisSize.min, children: [
                  Padding(
                    padding: const EdgeInsets.all(22),
                    child: Text(snapshot.error.toString().replaceFirst('Exception: ', ''), textAlign: TextAlign.center),
                  ),
                  TextButton(onPressed: _refresh, child: const Text('다시 불러오기')),
                ]),
              );
            }
            final data = snapshot.data!;
            return RefreshIndicator(
              onRefresh: _refresh,
              child: ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.all(16),
                children: [
                  const Text('작성 가능한 리뷰', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
                  const SizedBox(height: 10),
                  if (data.eligiblePurchases.isEmpty)
                    const _ReviewNotice(text: '리뷰를 작성할 수 있는 구매 확정 상품이 없습니다.'),
                  ...data.eligiblePurchases.map((purchase) => _EligiblePurchaseTile(
                        purchase: purchase,
                        onReview: () => _writeReview(purchase),
                      )),
                  const SizedBox(height: 22),
                  const Text('내가 작성한 리뷰', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
                  const SizedBox(height: 10),
                  if (data.reviews.isEmpty)
                    const _ReviewNotice(text: '작성한 리뷰가 없습니다.'),
                  ...data.reviews.map((review) => _ReviewTile(review: review)),
                ],
              ),
            );
          },
        ),
      );
}

class _ReviewData {
  const _ReviewData({required this.eligiblePurchases, required this.reviews});
  final List<Map<String, dynamic>> eligiblePurchases;
  final List<Map<String, dynamic>> reviews;
}

class _EligiblePurchaseTile extends StatelessWidget {
  const _EligiblePurchaseTile({required this.purchase, required this.onReview});
  final Map<String, dynamic> purchase;
  final VoidCallback onReview;

  @override
  Widget build(BuildContext context) {
    final purchaseCode = purchase['purchase_item_code']?.toString() ?? '';
    final productCode = purchase['sell_product_sell_product_code']?.toString() ?? '';
    return Card(
      elevation: 0,
      margin: const EdgeInsets.only(bottom: 8),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: const BorderSide(color: Color(0xFFEAECF2)),
      ),
      child: ListTile(
        leading: const CircleAvatar(
          backgroundColor: Color(0xFFECEAFF),
          child: Icon(Icons.rate_review_outlined, color: Color(0xFF6658E8)),
        ),
        title: Text(productCode, maxLines: 1, overflow: TextOverflow.ellipsis),
        subtitle: Text('구매 코드 $purchaseCode', maxLines: 2, overflow: TextOverflow.ellipsis),
        trailing: TextButton(onPressed: onReview, child: const Text('리뷰 작성')),
      ),
    );
  }
}

class _ReviewTile extends StatelessWidget {
  const _ReviewTile({required this.review});
  final Map<String, dynamic> review;

  @override
  Widget build(BuildContext context) {
    final rating = (review['review_rating'] as num?)?.toInt() ?? 0;
    final code = review['review_code']?.toString() ?? '';
    return Card(
      elevation: 0,
      margin: const EdgeInsets.only(bottom: 8),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: const BorderSide(color: Color(0xFFEAECF2)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(15),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Text(List<String>.filled(rating.clamp(0, 5).toInt(), '★').join(),
                style: const TextStyle(color: Color(0xFFF2A900), fontSize: 18)),
            const Spacer(),
            Text(_formatDate(review['review_date']?.toString() ?? ''),
                style: const TextStyle(color: Color(0xFF858B9A), fontSize: 12)),
          ]),
          const SizedBox(height: 7),
          Text(review['review_contents']?.toString() ?? ''),
          const SizedBox(height: 8),
          SelectableText('리뷰 코드  $code', style: const TextStyle(color: Color(0xFF858B9A), fontSize: 11)),
          Text('상품 코드  ${review['sell_product_sell_product_code'] ?? ''}',
              style: const TextStyle(color: Color(0xFF858B9A), fontSize: 11)),
        ]),
      ),
    );
  }
}

class _ReviewFormDialog extends StatefulWidget {
  const _ReviewFormDialog();
  @override
  State<_ReviewFormDialog> createState() => _ReviewFormDialogState();
}

class _ReviewFormDialogState extends State<_ReviewFormDialog> {
  final _controller = TextEditingController();
  int _rating = 5;
  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
        title: const Text('리뷰 작성'),
        content: SizedBox(
          width: 400,
          child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: List.generate(5, (index) => IconButton(
                  onPressed: () => setState(() => _rating = index + 1),
                  icon: Icon(index < _rating ? Icons.star_rounded : Icons.star_outline_rounded,
                      color: const Color(0xFFF2A900)),
                  tooltip: '${index + 1}점',
                ))),
            TextField(
              controller: _controller,
              maxLength: 500,
              maxLines: 5,
              decoration: const InputDecoration(
                hintText: '상품에 대한 후기를 작성해주세요.',
                border: OutlineInputBorder(),
              ),
            ),
          ]),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('취소')),
          FilledButton(
            onPressed: () {
              final text = _controller.text.trim();
              if (text.isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('리뷰 내용을 입력해주세요.')));
                return;
              }
              Navigator.pop(context, _ReviewDraft(rating: _rating, contents: text));
            },
            child: const Text('등록'),
          ),
        ],
      );
}

class _ReviewDraft {
  const _ReviewDraft({required this.rating, required this.contents});
  final int rating;
  final String contents;
}

class _ReviewNotice extends StatelessWidget {
  const _ReviewNotice({required this.text});
  final String text;
  @override
  Widget build(BuildContext context) => Container(
        width: double.infinity,
        padding: const EdgeInsets.all(17),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: const Color(0xFFEAECF2)),
        ),
        child: Text(text, textAlign: TextAlign.center, style: const TextStyle(color: Color(0xFF747887))),
      );
}

Map<String, dynamic> _decode(http.Response response) {
  try {
    final value = jsonDecode(utf8.decode(response.bodyBytes));
    if (value is Map<String, dynamic>) return value;
  } catch (_) {}
  return <String, dynamic>{};
}

String _error(http.Response response, [Map<String, dynamic>? body]) =>
    (body ?? _decode(response))['detail']?.toString() ?? '요청에 실패했습니다. (${response.statusCode})';

bool _isConfirmed(String? value) =>
    value?.trim() == '구매확정' || value?.trim() == '구매 확정';

String _formatDate(String value) {
  final parsed = DateTime.tryParse(value);
  if (parsed == null) return value.replaceFirst('T', ' ');
  final date = parsed.toLocal();
  String two(int number) => number.toString().padLeft(2, '0');
  return '${date.year}-${two(date.month)}-${two(date.day)} ${two(date.hour)}:${two(date.minute)}';
}
