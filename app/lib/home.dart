import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

import 'api_config.dart';
import 'chat.dart';
import 'inspection_request.dart';
import 'market_product.dart';
import 'my_info.dart';
import 'post_item.dart';
import 'product_detail.dart';
import 'wishlist.dart';

class HomePage extends StatefulWidget {
  const HomePage(
      {super.key,
      required this.token,
      required this.role,
      required this.account,
      this.onLogout});

  final String token;
  final String role;
  final Map<String, dynamic> account;
  final VoidCallback? onLogout;

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  static const _labels = ['홈', '관심상품', '상품등록', '채팅', '내정보'];
  static const _icons = [
    Icons.home_rounded,
    Icons.favorite_border_rounded,
    Icons.add_box_outlined,
    Icons.chat_bubble_outline_rounded,
    Icons.person_outline_rounded,
  ];

  final _searchController = TextEditingController();
  final Set<String> _wishlistCodes = <String>{};
  String? _wishlistError;
  int _selectedIndex = 0;
  bool _searchOpen = false;
  String _query = '';
  late Future<List<MarketProduct>> _productsFuture;

  @override
  void initState() {
    super.initState();
    _productsFuture = _fetchProducts();
    _loadWishlist();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<List<MarketProduct>> _fetchProducts() async {
    final response = await http
        .get(Uri.parse('$apiBaseUrl/sell_product'))
        .timeout(const Duration(seconds: 15));
    if (response.statusCode != 200) {
      throw Exception('상품 목록 요청 실패 (${response.statusCode})');
    }
    final decoded = jsonDecode(utf8.decode(response.bodyBytes));
    if (decoded is! List) {
      throw const FormatException('상품 목록 응답 형식이 올바르지 않습니다.');
    }
    return decoded
        .map((item) =>
            MarketProduct.fromJson(Map<String, dynamic>.from(item as Map)))
        .toList();
  }

  Future<void> _reloadProducts() async {
    final next = _fetchProducts();
    setState(() => _productsFuture = next);
    try {
      await next;
    } catch (_) {
      // The product list shows a retry state if the request fails.
    }
  }

  Future<void> _refreshWishlistAndProducts() async {
    await _reloadProducts();
    await _loadWishlist();
  }

  Future<void> _onProductCreated() async {
    await _reloadProducts();
    if (!mounted) return;
    setState(() => _selectedIndex = 0);
    await _loadWishlist();
  }

  String? get _userId =>
      widget.role == 'user' ? widget.account['user_id']?.toString() : null;

  Future<void> _loadWishlist() async {
    final userId = _userId;
    if (userId == null || userId.isEmpty) return;
    if (mounted) setState(() => _wishlistError = null);
    try {
      final response = await http.get(
        Uri.parse('$apiBaseUrl/wishlist/${Uri.encodeComponent(userId)}'),
        headers: {'Authorization': 'Bearer ${widget.token}'},
      ).timeout(const Duration(seconds: 15));
      if (response.statusCode != 200) {
        throw Exception(_readApiError(response));
      }
      final decoded = jsonDecode(utf8.decode(response.bodyBytes));
      if (decoded is! List) {
        throw const FormatException('관심 상품 응답 형식이 올바르지 않습니다.');
      }
      final savedCodes = decoded
          .whereType<Map>()
          .where((row) {
            final status = row['wishlist_status']?.toString();
            return status == '\uad00\uc2ec' || status == '\uad00\uc2ec\uc911';
          })
          .map((row) => row['sell_product_sell_product_code']?.toString() ?? '')
          .where((code) => code.isNotEmpty)
          .toSet();
      Set<String> saleCodes;
      try {
        saleCodes = (await _productsFuture)
            .where((product) => product.status == '\ud310\ub9e4\uc911')
            .map((product) => product.code)
            .toSet();
      } catch (_) {
        // Keep server favorites if the catalog request failed; the catalog can retry.
        saleCodes = savedCodes;
      }
      final staleCodes = savedCodes.difference(saleCodes);
      if (staleCodes.isNotEmpty && saleCodes != savedCodes) {
        await Future.wait(staleCodes.map((code) async {
          try {
            await http.delete(
              Uri.parse(
                  '$apiBaseUrl/wishlist/${Uri.encodeComponent(userId)}/${Uri.encodeComponent(code)}'),
              headers: {'Authorization': 'Bearer ${widget.token}'},
            );
          } catch (_) {
            // The item stays hidden by the active-catalog filter below.
          }
        }));
      }
      if (!mounted) return;
      setState(() {
        _wishlistError = null;
        _wishlistCodes
          ..clear()
          ..addAll(savedCodes.intersection(saleCodes));
      });
    } catch (error) {
      if (!mounted) return;
      setState(() => _wishlistError =
          error.toString().replaceFirst('Exception: ', ''));
    }
  }

  Future<void> _toggleWishlist(MarketProduct product) async {
    final userId = _userId;
    if (userId == null || userId.isEmpty) {
      _showMessage('관심상품은 일반 회원 계정에서 사용할 수 있습니다.');
      return;
    }
    final wasSaved = _wishlistCodes.contains(product.code);
    setState(() {
      if (wasSaved) {
        _wishlistCodes.remove(product.code);
      } else {
        _wishlistCodes.add(product.code);
      }
    });
    try {
      final uri = wasSaved
          ? Uri.parse(
              '$apiBaseUrl/wishlist/${Uri.encodeComponent(userId)}/${Uri.encodeComponent(product.code)}')
          : Uri.parse('$apiBaseUrl/wishlist');
      final response = wasSaved
          ? await http.delete(uri, headers: {
              'Authorization': 'Bearer ${widget.token}',
            })
          : await http.post(
              uri,
              headers: {
                'Content-Type': 'application/json',
                'Authorization': 'Bearer ${widget.token}',
              },
              body: jsonEncode({
                'user_user_id': userId,
                'sell_product_sell_product_code': product.code,
              }),
            );
      if (response.statusCode < 200 || response.statusCode >= 300) {
        throw Exception('관심상품 저장 실패 (${response.statusCode})');
      }
    } catch (_) {
      if (!mounted) return;
      setState(() {
        if (wasSaved) {
          _wishlistCodes.add(product.code);
        } else {
          _wishlistCodes.remove(product.code);
        }
      });
      _showMessage('관심상품을 저장하지 못했습니다. 다시 시도해 주세요.');
    }
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), behavior: SnackBarBehavior.floating),
    );
  }

  void _openProduct(MarketProduct product) {
    Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder: (_) => ProductDetailPage(
          product: product,
          token: widget.token,
          canTrade: widget.role == 'user',
          isWishlisted: _wishlistCodes.contains(product.code),
          onToggleWishlist: () => _toggleWishlist(product),
          onReturnedFromPurchase: _refreshWishlistAndProducts,
        ),
      ),
    );
  }

  void _showNotifications() {
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (context) => const SafeArea(
        child: SizedBox(
          height: 230,
          child: Center(
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              Icon(Icons.notifications_none_rounded,
                  size: 42, color: Color(0xFF9AA0AD)),
              SizedBox(height: 12),
              Text('새 알림이 없습니다',
                  style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
              SizedBox(height: 6),
              Text('알림 기능은 준비 중입니다.',
                  style: TextStyle(color: Color(0xFF858B9A))),
            ]),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(
          title: _searchOpen
              ? TextField(
                  controller: _searchController,
                  autofocus: true,
                  textInputAction: TextInputAction.search,
                  onSubmitted: (value) => setState(() => _query = value.trim()),
                  decoration: const InputDecoration(
                      hintText: '상품 검색',
                      border: InputBorder.none,
                      isDense: true),
                )
              : const Text('POKEM',
                  style: TextStyle(
                      fontWeight: FontWeight.w900, letterSpacing: 1.4)),
          actions: [
            IconButton(
              tooltip: _searchOpen ? '검색 닫기' : '검색',
              onPressed: () => setState(() {
                _searchOpen = !_searchOpen;
                if (!_searchOpen) {
                  _searchController.clear();
                  _query = '';
                }
              }),
              icon: Icon(
                  _searchOpen ? Icons.close_rounded : Icons.search_rounded),
            ),
            IconButton(
                tooltip: '알림',
                onPressed: _showNotifications,
                icon: const Icon(Icons.notifications_none_rounded)),
            const SizedBox(width: 4),
          ],
        ),
        body: IndexedStack(
          index: _selectedIndex,
          children: [
            _buildHomeTab(),
            if (widget.role == 'user')
              WishlistPage(
                productsFuture: _productsFuture,
                savedCodes: _wishlistCodes,
                onToggleWishlist: _toggleWishlist,
                onOpenProduct: _openProduct,
                loadError: _wishlistError,
                onRetry: _refreshWishlistAndProducts,
              )
            else
              const Center(child: Text('관심상품은 일반 회원 전용 기능입니다.')),
            if (widget.role == 'user')
              PostItemPage(token: widget.token, onCreated: _onProductCreated)
            else
              const Center(child: Text('상품 등록은 일반 회원 전용 기능입니다.')),
            const ChatPage(),
            MyInfoPage(
                account: widget.account,
                role: widget.role,
                token: widget.token,
                onLogout: widget.onLogout),
          ],
        ),
        bottomNavigationBar: NavigationBar(
          selectedIndex: _selectedIndex,
          onDestinationSelected: (index) {
            setState(() => _selectedIndex = index);
            if (index == 1 && widget.role == 'user') {
              _refreshWishlistAndProducts();
            }
          },
          destinations: List.generate(
            _labels.length,
            (index) => NavigationDestination(
                icon: Icon(_icons[index]),
                selectedIcon:
                    Icon(_icons[index], color: const Color(0xFF6658E8)),
                label: _labels[index]),
          ),
        ),
      );

  Widget _buildHomeTab() => FutureBuilder<List<MarketProduct>>(
        future: _productsFuture,
        builder: (context, snapshot) {
          final allProducts = snapshot.data ?? const <MarketProduct>[];
          final products = allProducts
              .where((product) => product.status == '판매중')
              .where((product) =>
                  _query.isEmpty ||
                  '${product.title} ${product.contents} ${product.code}'
                      .toLowerCase()
                      .contains(_query.toLowerCase()))
              .toList();
          return RefreshIndicator(
            onRefresh: _reloadProducts,
            child: CustomScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              slivers: [
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(18, 12, 18, 8),
                  sliver: SliverToBoxAdapter(
                    child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('카드마켓',
                              style: TextStyle(
                                  fontSize: 22,
                                  fontWeight: FontWeight.w800,
                                  color: Color(0xFF20283B))),
                          const SizedBox(height: 5),
                          const Text('마음에 드는 카드를 발견해 보세요.',
                              style: TextStyle(color: Color(0xFF858B9A))),
                          if (widget.role == 'user') ...[
                            const SizedBox(height: 18),
                          InkWell(
                            onTap: () => Navigator.of(context).push<void>(
                                MaterialPageRoute<void>(
                                    builder: (_) => InspectionRequestPage(
                                        token: widget.token))),
                            borderRadius: BorderRadius.circular(20),
                            child: Container(
                              padding: const EdgeInsets.all(19),
                              decoration: BoxDecoration(
                                  gradient: const LinearGradient(colors: [
                                    Color(0xFF7668F2),
                                    Color(0xFF5144C8)
                                  ]),
                                  borderRadius: BorderRadius.circular(20)),
                              child: const Row(children: [
                                Icon(Icons.verified_outlined,
                                    color: Colors.white, size: 32),
                                SizedBox(width: 14),
                                Expanded(
                                    child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                      Text('검수 신청',
                                          style: TextStyle(
                                              color: Colors.white,
                                              fontWeight: FontWeight.w800,
                                              fontSize: 17)),
                                      SizedBox(height: 4),
                                      Text('카드 검수를 신청해 보세요',
                                          style: TextStyle(
                                              color: Color(0xFFE5E2FF),
                                              fontSize: 13))
                                    ])),
                                Icon(Icons.chevron_right_rounded,
                                    color: Colors.white),
                              ]),
                            ),
                          ),
                          ],
                          const SizedBox(height: 23),
                          Text(_query.isEmpty ? '등록된 상품' : '검색 결과',
                              style: const TextStyle(
                                  fontSize: 20,
                                  fontWeight: FontWeight.w800,
                                  color: Color(0xFF20283B))),
                          const SizedBox(height: 12),
                        ]),
                  ),
                ),
                if (snapshot.connectionState == ConnectionState.waiting &&
                    !snapshot.hasData)
                  const SliverFillRemaining(
                      hasScrollBody: false,
                      child: Center(child: CircularProgressIndicator()))
                else if (snapshot.hasError)
                  SliverFillRemaining(
                      hasScrollBody: false,
                      child: _EmptyState(
                          icon: Icons.wifi_off_rounded,
                          message: '상품을 불러오지 못했어요.',
                          onRetry: _reloadProducts))
                else if (products.isEmpty)
                  SliverFillRemaining(
                      hasScrollBody: false,
                      child: _EmptyState(
                          icon: Icons.style_outlined,
                          message: _query.isEmpty
                              ? '등록된 상품이 아직 없어요.'
                              : '검색 결과가 없습니다.'))
                else
                  SliverPadding(
                    padding: const EdgeInsets.fromLTRB(14, 0, 14, 22),
                    sliver: SliverGrid.builder(
                      itemCount: products.length,
                      gridDelegate:
                          const SliverGridDelegateWithFixedCrossAxisCount(
                              crossAxisCount: 2,
                              mainAxisSpacing: 12,
                              crossAxisSpacing: 12,
                              childAspectRatio: 0.68),
                      itemBuilder: (context, index) => ProductCard(
                        product: products[index],
                        isWishlisted:
                            _wishlistCodes.contains(products[index].code),
                        onFavorite: () => _toggleWishlist(products[index]),
                        onTap: () => _openProduct(products[index]),
                      ),
                    ),
                  ),
              ],
            ),
          );
        },
      );
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.icon, required this.message, this.onRetry});
  final IconData icon;
  final String message;
  final Future<void> Function()? onRetry;

  @override
  Widget build(BuildContext context) => Center(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Icon(icon, size: 42, color: const Color(0xFF9AA0AD)),
          const SizedBox(height: 10),
          Text(message, style: const TextStyle(color: Color(0xFF737A8A))),
          if (onRetry != null)
            TextButton(onPressed: onRetry, child: const Text('다시 시도')),
        ]),
      );
}

String _readApiError(http.Response response) {
  try {
    final decoded = jsonDecode(utf8.decode(response.bodyBytes));
    if (decoded is Map<String, dynamic> && decoded['detail'] is String) {
      return decoded['detail'] as String;
    }
  } catch (_) {}
  return '요청에 실패했습니다. (${response.statusCode})';
}
