import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pokem_app/vm/auth/login_vm.dart';
import 'package:pokem_app/vm/push/push_vm.dart';

class PushBridge extends ConsumerStatefulWidget {
  const PushBridge({super.key, required this.child, required this.onOpen});
  final Widget child;
  final ValueChanged<PushTarget> onOpen;
  @override
  ConsumerState<PushBridge> createState() => _PushBridgeState();
}

class _PushBridgeState extends ConsumerState<PushBridge>
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
    if (state == AppLifecycleState.resumed) {
      ref.read(pushVmProvider.notifier).synchronize();
    }
  }

  void _open(PushTarget target) {
    if (ref.read(loginVmProvider).session?.account.id == target.ownerId) {
      widget.onOpen(target);
    }
  }

  @override
  Widget build(BuildContext context) {
    ref.listen(pushVmProvider, (previous, next) {
      final opened = next.opened;
      final foreground = next.foreground;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        if (opened != null && opened != previous?.opened) _open(opened);
        if (foreground != null &&
            foreground != previous?.foreground &&
            ref.read(loginVmProvider).session?.account.id ==
                foreground.ownerId) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: const Text('검수가 완료되었습니다.'),
              action: SnackBarAction(
                label: '보기',
                onPressed: () => _open(foreground),
              ),
            ),
          );
        }
      });
    });
    return widget.child;
  }
}
