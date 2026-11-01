import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pokem_app/core/providers/data_providers.dart';
import 'package:pokem_app/model/products/card_info_guide.dart';
import 'package:pokem_app/vm/auth/login_vm.dart';
export 'package:pokem_app/model/products/card_info_guide.dart';

class ProductGuideVm extends Notifier<ProductGuidePreference> {
  int _generation = 0;
  String _owner = 'guest';
  @override
  ProductGuidePreference build() {
    _owner =
        ref.watch(loginVmProvider.select((s) => s.session?.account.id)) ??
        'guest';
    final generation = ++_generation;
    final owner = _owner;
    Future.microtask(() async {
      bool hidden = false;
      try {
        hidden = await ref.read(productGuideRepositoryProvider).hidden(owner);
      } catch (_) {
        /* Show the guide if the preference cannot be read. */
      }
      if (ref.mounted && generation == _generation) {
        state = ProductGuidePreference(
          ready: true,
          hidden: hidden,
          selected: hidden,
        );
      }
    });
    return const ProductGuidePreference();
  }

  void prepare() {
    if (!state.saving) {
      state = ProductGuidePreference(
        ready: state.ready,
        hidden: state.hidden,
        selected: state.hidden,
      );
    }
  }

  void select(bool value) {
    if (!state.saving) {
      state = ProductGuidePreference(
        ready: state.ready,
        hidden: state.hidden,
        selected: value,
      );
    }
  }

  Future<bool> confirm() async {
    if (!state.ready || state.saving) return false;
    if (state.selected == state.hidden) return true;
    final generation = _generation;
    final owner = _owner;
    final before = state;
    state = ProductGuidePreference(
      ready: true,
      hidden: before.hidden,
      selected: before.selected,
      saving: true,
    );
    try {
      await ref
          .read(productGuideRepositoryProvider)
          .save(owner, before.selected);
      if (!ref.mounted || generation != _generation) return false;
      state = ProductGuidePreference(
        ready: true,
        hidden: before.selected,
        selected: before.selected,
      );
      return true;
    } catch (_) {
      if (ref.mounted && generation == _generation) {
        state = ProductGuidePreference(
          ready: true,
          hidden: before.hidden,
          selected: before.selected,
          error: '설정을 저장하지 못했습니다. 다시 시도해주세요.',
        );
      }
      return false;
    }
  }
}

final productGuideVmProvider =
    NotifierProvider.autoDispose<ProductGuideVm, ProductGuidePreference>(
      ProductGuideVm.new,
    );
