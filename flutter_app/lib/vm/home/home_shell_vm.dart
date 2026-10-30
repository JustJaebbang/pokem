import 'package:flutter_riverpod/flutter_riverpod.dart';

class HomeShellVm extends Notifier<int> {
  @override
  int build() => 0;
  void onProductCreated() => state = 0;
  void select(int index) => state = index;
}

final homeShellVmProvider = NotifierProvider.autoDispose<HomeShellVm, int>(
  HomeShellVm.new,
);
