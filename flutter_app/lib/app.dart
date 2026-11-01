import 'package:pokem_app/core/theme/app_theme.dart';
import 'package:pokem_app/view/push/push_bridge.dart';
import 'package:pokem_app/view/inspection/inspection_results_view.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:pokem_app/vm/auth/login_vm.dart';
import 'package:pokem_app/view/auth/login_view.dart';
import 'package:pokem_app/view/auth/session_view.dart';
import 'package:pokem_app/view/home/home_shell.dart';
import 'package:pokem_app/model/auth/auth_session.dart';
import 'package:pokem_app/view/manager/manager_dashboard_view.dart';
import 'package:pokem_app/view/director/director_dashboard_view.dart';

final appNavigatorKeyProvider = Provider<GlobalKey<NavigatorState>>(
  (ref) => GlobalKey<NavigatorState>(),
);

class PokemApp extends ConsumerWidget {
  const PokemApp({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(loginVmProvider);
    final navigatorKey = ref.watch(appNavigatorKeyProvider);
    ref.listen(loginVmProvider, (previous, next) {
      if (previous?.session != null && next.session == null) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (context.mounted && ref.read(loginVmProvider).session == null) {
            navigatorKey.currentState?.popUntil((route) => route.isFirst);
          }
        });
      }
    });
    return MaterialApp(
      title: 'POKEM',
      builder: (context, child) => PushBridge(
        child: child ?? const SizedBox.shrink(),
        onOpen: (target) {
          navigatorKey.currentState?.push(
            MaterialPageRoute<void>(
              builder: (_) =>
                  InspectionResultsView(number: target.requestNumber),
            ),
          );
        },
      ),
      navigatorKey: navigatorKey,
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      home: state.restoring
          ? const Scaffold(body: Center(child: CircularProgressIndicator()))
          : state.session == null
          ? const LoginView()
          : state.isCustomer
          ? const HomeShell()
          : state.session?.account.role == AccountRole.manager
          ? const ManagerDashboardView()
          : state.session?.account.role == AccountRole.director
          ? const DirectorDashboardView()
          : const SessionView(),
    );
  }
}
