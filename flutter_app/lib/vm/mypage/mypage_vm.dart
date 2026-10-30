import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pokem_app/vm/auth/login_vm.dart';

enum MypageMode { selling, buying }

class MypageVm extends Notifier<MypageMode> {
  @override
  MypageMode build() {
    ref.watch(loginVmProvider.select((s) => s.session?.account.id));
    return MypageMode.selling;
  }

  void select(MypageMode mode) => state = mode;
}

final mypageVmProvider = NotifierProvider.autoDispose<MypageVm, MypageMode>(
  MypageVm.new,
);
