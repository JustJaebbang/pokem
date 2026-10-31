import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pokem_app/model/notifications/app_notification.dart';
import 'package:pokem_app/vm/notifications/notifications_vm.dart';
import 'package:pokem_app/core/formatters/purchase_time.dart';
import 'package:pokem_app/view/inspection/inspection_fee_view.dart';
import 'package:pokem_app/view/inspection/inspection_results_view.dart';
import 'package:pokem_app/view/purchase/seller_cancel_view.dart';
import 'package:pokem_app/view/purchase/purchase_cancel_view.dart';
import 'package:pokem_app/view/wallet/wallet_view.dart';

class NotificationsView extends ConsumerWidget {
  const NotificationsView({super.key});
  Widget? destination(AppNotification item) => switch (item.target) {
    'inspection_fee' when item.code != null => InspectionFeeView(
      number: item.code!,
    ),
    'inspection_result' when item.code != null => InspectionResultsView(
      number: item.code!,
    ),
    'seller_cancel' => const SellerCancelView(),
    'purchase_cancel' when item.code != null => PurchaseCancelView(
      code: item.code!,
    ),
    'wallet' => const WalletView(),
    _ => null,
  };
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final result = ref.watch(notificationsVmProvider);
    return Scaffold(
      appBar: AppBar(
        title: const Text('알림'),
        actions: [
          TextButton(
            onPressed:
                result.asData?.value.unread == 0 ||
                    result.asData == null ||
                    result.asData!.value.saving
                ? null
                : () => ref.read(notificationsVmProvider.notifier).markRead(),
            child: const Text('모두 읽음'),
          ),
          IconButton(
            tooltip: '알림 새로고침',
            onPressed: result.isLoading
                ? null
                : () => ref.read(notificationsVmProvider.notifier).refresh(),
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: result.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(e is NotificationsException ? e.message : '알림을 불러오지 못했습니다.'),
              TextButton(
                onPressed: () =>
                    ref.read(notificationsVmProvider.notifier).refresh(),
                child: const Text('다시 시도'),
              ),
            ],
          ),
        ),
        data: (data) => RefreshIndicator(
          onRefresh: () async {
            ref.read(notificationsVmProvider.notifier).refresh();
            try {
              await ref.read(notificationsVmProvider.future);
            } catch (_) {}
          },
          child: ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            children: [
              if (data.error != null)
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Text(data.error!),
                ),
              if (data.items.isEmpty)
                const Padding(
                  padding: EdgeInsets.all(32),
                  child: Text('알림이 없습니다.'),
                ),
              for (final item in data.items)
                ListTile(
                  leading: Icon(
                    data.readIds.contains(item.id)
                        ? Icons.notifications_none
                        : Icons.notifications_active_outlined,
                  ),
                  title: Text(
                    item.title,
                    style: TextStyle(
                      fontWeight: data.readIds.contains(item.id)
                          ? FontWeight.normal
                          : FontWeight.bold,
                    ),
                  ),
                  subtitle: Text(
                    [
                      item.body,
                      if (item.date != null &&
                          DateTime.tryParse(item.date!) != null)
                        formatPurchaseTime(item.date),
                    ].join(' · '),
                  ),
                  onTap: data.saving
                      ? null
                      : () async {
                          await ref
                              .read(notificationsVmProvider.notifier)
                              .markRead(id: item.id);
                          if (!context.mounted) return;
                          final page = destination(item);
                          if (page != null) {
                            await Navigator.of(context).push(
                              MaterialPageRoute<void>(builder: (_) => page),
                            );
                          }
                          if (context.mounted) {
                            ref
                                .read(notificationsVmProvider.notifier)
                                .refresh();
                          }
                        },
                ),
            ],
          ),
        ),
      ),
    );
  }
}
