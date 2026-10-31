import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pokem_app/view/purchase/purchase_history_view.dart';
import 'package:pokem_app/view/sales/sales_view.dart';
import 'package:pokem_app/vm/mypage/mypage_vm.dart';

class MypageMenu extends ConsumerWidget {
  const MypageMenu({super.key, required this.onWishlist});
  final VoidCallback onWishlist;
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final mode = ref.watch(mypageVmProvider);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SizedBox(height: 24),
        Center(
          child: SegmentedButton<MypageMode>(
            segments: const [
              ButtonSegment(value: MypageMode.selling, label: Text('판매')),
              ButtonSegment(value: MypageMode.buying, label: Text('구매')),
            ],
            selected: {mode},
            showSelectedIcon: false,
            onSelectionChanged: (selected) =>
                ref.read(mypageVmProvider.notifier).select(selected.single),
            style: ButtonStyle(
              minimumSize: const WidgetStatePropertyAll(Size(88, 46)),
              shape: WidgetStatePropertyAll(
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
              ),
              backgroundColor: WidgetStateProperty.resolveWith(
                (states) => states.contains(WidgetState.selected)
                    ? Theme.of(context).colorScheme.primary
                    : Theme.of(context).colorScheme.surface,
              ),
              foregroundColor: WidgetStateProperty.resolveWith(
                (states) => states.contains(WidgetState.selected)
                    ? Theme.of(context).colorScheme.onPrimary
                    : Theme.of(context).colorScheme.onSurface,
              ),
            ),
          ),
        ),
        const SizedBox(height: 24),
        if (mode == MypageMode.selling)
          OutlinedButton(
            onPressed: () => Navigator.of(
              context,
            ).push(MaterialPageRoute<void>(builder: (_) => const SalesView())),
            style: OutlinedButton.styleFrom(
              minimumSize: const Size.fromHeight(80),
            ),
            child: const Text('판매내역'),
          )
        else
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: onWishlist,
                  style: OutlinedButton.styleFrom(
                    minimumSize: const Size.fromHeight(80),
                  ),
                  child: const Text('관심상품'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: OutlinedButton(
                  onPressed: () => Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) => const PurchaseHistoryView(),
                    ),
                  ),
                  style: OutlinedButton.styleFrom(
                    minimumSize: const Size.fromHeight(80),
                  ),
                  child: const Text('구매내역'),
                ),
              ),
            ],
          ),
      ],
    );
  }
}
