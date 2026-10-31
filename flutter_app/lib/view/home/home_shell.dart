import 'package:pokem_app/view/products/product_search_view.dart';
import 'package:pokem_app/view/notifications/notification_bell.dart';
import 'package:pokem_app/vm/notifications/notifications_vm.dart';
import 'package:pokem_app/view/mypage/pending_actions_card.dart';
import 'package:pokem_app/view/profile/quit_view.dart';
import 'package:pokem_app/view/inspection/return_view.dart';
import 'package:pokem_app/view/inspection/inspection_history_view.dart';
import 'package:pokem_app/view/profile/profile_view.dart';
import 'package:pokem_app/view/mypage/mypage_menu.dart';
import 'package:pokem_app/view/wallet/wallet_view.dart';
import 'package:pokem_app/view/chat/chat_rooms_view.dart';
import 'package:pokem_app/view/wishlist/wishlist_view.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:pokem_app/vm/auth/login_vm.dart';
import 'package:pokem_app/view/home/home_view.dart';
import 'package:pokem_app/view/products/product_create_view.dart';
import 'package:pokem_app/model/products/product.dart';
import 'package:pokem_app/vm/home/home_shell_vm.dart';

class HomeShell extends ConsumerWidget {
  const HomeShell({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final index = ref.watch(homeShellVmProvider);
    final state = ref.watch(loginVmProvider);
    final account = state.session?.account;
    const names = ['홈', '관심', '등록', '채팅', '마이페이지'];
    const icons = [
      Icons.home_outlined,
      Icons.favorite_border,
      Icons.add_circle_outline,
      Icons.chat_bubble_outline,
      Icons.person_outline,
    ];
    return Scaffold(
      appBar: AppBar(
        title: Text(index == 0 ? '포켐' : names[index]),
        actions: [
          IconButton(
            tooltip: index == 1 ? '관심상품 검색' : '상품 검색',
            icon: const Icon(Icons.search),
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute<void>(
                builder: (_) => ProductSearchView(wishlistOnly: index == 1),
              ),
            ),
          ),
          const NotificationBell(),
        ],
      ),
      body: IndexedStack(
        index: index,
        children: [
          const HomeView(),
          const WishlistView(),
          const SizedBox.shrink(),
          index == 3 ? const ChatRoomsView() : const SizedBox.shrink(),
          SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Icon(Icons.account_circle_outlined, size: 72),
                const SizedBox(height: 16),
                Text(
                  account?.name ?? '',
                  style: Theme.of(context).textTheme.headlineSmall,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 8),
                Text(
                  '${account?.role.label ?? ''} · ${account?.id ?? ''}',
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 24),
                if (index == 4) const WalletSummary(),
                if (index == 4) const PendingActionsCard(),
                MypageMenu(
                  onWishlist: () =>
                      ref.read(homeShellVmProvider.notifier).select(1),
                ),
                ListTile(
                  title: const Text('회원정보 수정'),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) => const ProfileView(),
                    ),
                  ),
                ),
                ListTile(
                  title: const Text('검수신청 내역'),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) => const InspectionHistoryView(),
                    ),
                  ),
                ),
                ListTile(
                  title: const Text('반환내역'),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute<void>(builder: (_) => const ReturnView()),
                  ),
                ),
                ListTile(
                  title: const Text('회원탈퇴'),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute<void>(builder: (_) => const QuitView()),
                  ),
                ),
                if (state.error != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 16),
                    child: Text(state.error!),
                  ),
                const SizedBox(height: 24),
                OutlinedButton(
                  onPressed: state.submitting
                      ? null
                      : () => ref.read(loginVmProvider.notifier).logout(),
                  child: const Text('로그아웃'),
                ),
              ],
            ),
          ),
        ],
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: index,
        onDestinationSelected: (value) async {
          if (value != 2) {
            ref.read(homeShellVmProvider.notifier).select(value);
            ref.invalidate(notificationsVmProvider);
            return;
          }
          final product = await Navigator.of(context).push<Product>(
            MaterialPageRoute(builder: (_) => const ProductCreateView()),
          );
          if (!context.mounted || product == null) return;
          ref.read(homeShellVmProvider.notifier).onProductCreated();
          ScaffoldMessenger.of(context)
              .showSnackBar(const SnackBar(content: Text('상품이 등록되었습니다.')));
        },
        destinations: [
          for (var i = 0; i < names.length; i++)
            NavigationDestination(icon: Icon(icons[i]), label: names[i]),
        ],
      ),
    );
  }
}
