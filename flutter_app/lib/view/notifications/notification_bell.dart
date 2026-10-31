import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pokem_app/vm/notifications/notifications_vm.dart';
import 'package:pokem_app/view/notifications/notifications_view.dart';

class NotificationBell extends ConsumerStatefulWidget {
  const NotificationBell({super.key});
  @override
  ConsumerState<NotificationBell> createState() => _NotificationBellState();
}

class _NotificationBellState extends ConsumerState<NotificationBell>
    with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && mounted) {
      ref.read(notificationsVmProvider.notifier).refresh();
    }
  }

  @override
  Widget build(BuildContext context) {
    final result = ref.watch(notificationsVmProvider);
    final unread = result.asData?.value.unread ?? 0;
    return IconButton(
      tooltip: result.hasError ? '알림 조회 실패 · 다시 확인' : '알림',
      icon: Badge(
        isLabelVisible: unread > 0,
        label: Text(unread > 99 ? '99+' : '$unread'),
        child: const Icon(Icons.notifications_none),
      ),
      onPressed: () async {
        ref.read(notificationsVmProvider.notifier).refresh();
        await Navigator.of(context).push(
          MaterialPageRoute<void>(builder: (_) => const NotificationsView()),
        );
        if (mounted) ref.read(notificationsVmProvider.notifier).refresh();
      },
    );
  }
}
