import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pokem_app/core/providers/data_providers.dart';
import 'package:pokem_app/model/auth/auth_session.dart';
import 'package:pokem_app/model/director/director_dashboard.dart';
import 'package:pokem_app/vm/auth/login_vm.dart';

enum DirectorSection {
  dashboard,
  analytics,
  approvals,
  withdrawals,
  managers,
  inventory,
}

class DirectorDashboardState {
  const DirectorDashboardState({
    this.data,
    this.loading = false,
    this.submitting = false,
    this.error,
    this.notice,
    this.section = DirectorSection.dashboard,
    this.query = '',
    this.selectedId,
  });
  final DirectorDashboard? data;
  final bool loading, submitting;
  final String? error, notice, selectedId;
  final DirectorSection section;
  final String query;
  DirectorDashboardState copyWith({
    DirectorDashboard? data,
    bool? loading,
    bool? submitting,
    String? error,
    String? notice,
    DirectorSection? section,
    String? query,
    String? selectedId,
    bool resetSelection = false,
  }) => DirectorDashboardState(
    data: data ?? this.data,
    loading: loading ?? this.loading,
    submitting: submitting ?? this.submitting,
    error: error,
    notice: notice,
    section: section ?? this.section,
    query: query ?? this.query,
    selectedId: resetSelection ? null : selectedId ?? this.selectedId,
  );
}

class DirectorDashboardVm extends Notifier<DirectorDashboardState> {
  @override
  DirectorDashboardState build() {
    ref.watch(loginVmProvider.select((state) => state.session));
    Future.microtask(refresh);
    return const DirectorDashboardState(loading: true);
  }

  String get _token {
    final session = ref.read(loginVmProvider).session;
    if (session == null ||
        session.isExpired ||
        session.account.role != AccountRole.director) {
      throw const DirectorException('총괄책임자 계정으로 로그인해주세요.', statusCode: 403);
    }
    return session.token;
  }

  Future<void> refresh() async {
    if (state.submitting) return;
    state = state.copyWith(loading: true);
    try {
      final data = await ref.read(directorRepositoryProvider).load(_token);
      if (ref.mounted) {
        state = state.copyWith(data: data, loading: false);
      }
    } catch (error) {
      if (ref.mounted) {
        state = state.copyWith(loading: false, error: _message(error));
      }
    }
  }

  void selectSection(DirectorSection section) =>
      state = state.copyWith(section: section, query: '', resetSelection: true);
  void search(String query) =>
      state = state.copyWith(query: query, resetSelection: true);
  void select(String id) => state = state.copyWith(selectedId: id);

  Future<bool> review(String number, String status) async {
    if (state.loading || state.submitting) return false;
    state = state.copyWith(submitting: true);
    try {
      await ref
          .read(directorRepositoryProvider)
          .reviewProposal(_token, number, status);
      if (!ref.mounted) return false;
      state = state.copyWith(submitting: false);
      await refresh();
      if (ref.mounted) {
        state = state.copyWith(notice: '품의를 $status 처리했습니다.');
      }
      return true;
    } catch (error) {
      if (ref.mounted) {
        state = state.copyWith(submitting: false, error: _message(error));
      }
      return false;
    }
  }

  String _message(Object error) =>
      error is DirectorException ? error.message : '총괄 데이터를 처리하지 못했습니다.';
}

final directorDashboardVmProvider =
    NotifierProvider.autoDispose<DirectorDashboardVm, DirectorDashboardState>(
      DirectorDashboardVm.new,
    );
