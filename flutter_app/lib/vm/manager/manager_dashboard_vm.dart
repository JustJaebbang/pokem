import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pokem_app/core/providers/data_providers.dart';
import 'package:pokem_app/model/manager/manager_dashboard.dart';
import 'package:pokem_app/model/auth/auth_session.dart';
import 'package:pokem_app/vm/auth/login_vm.dart';

enum ManagerSection { requests, inspections, consignments }

class ManagerDashboardState {
  const ManagerDashboardState({
    this.data,
    this.loading = false,
    this.submitting = false,
    this.error,
    this.notice,
    this.section = ManagerSection.requests,
    this.query = '',
    this.status,
    this.selectedId,
  });
  final ManagerDashboard? data;
  final bool loading, submitting;
  final String? error, notice, status, selectedId;
  final ManagerSection section;
  final String query;
  ManagerDashboardState copyWith({
    ManagerDashboard? data,
    bool? loading,
    bool? submitting,
    String? error,
    String? notice,
    ManagerSection? section,
    String? query,
    String? status,
    String? selectedId,
    bool resetSelection = false,
    bool resetStatus = false,
  }) => ManagerDashboardState(
    data: data ?? this.data,
    loading: loading ?? this.loading,
    submitting: submitting ?? this.submitting,
    error: error,
    notice: notice,
    section: section ?? this.section,
    query: query ?? this.query,
    status: resetStatus ? null : status ?? this.status,
    selectedId: resetSelection ? null : selectedId ?? this.selectedId,
  );
}

class ManagerDashboardVm extends Notifier<ManagerDashboardState> {
  @override
  ManagerDashboardState build() {
    // Recreate state whenever the authenticated account changes.
    ref.watch(loginVmProvider.select((value) => value.session));
    Future.microtask(refresh);
    return const ManagerDashboardState(loading: true);
  }

  String get _token {
    final session = ref.read(loginVmProvider).session;
    if (session == null ||
        session.isExpired ||
        session.account.role != AccountRole.manager) {
      throw const ManagerException('매니저 계정으로 로그인해주세요.', statusCode: 403);
    }
    return session.token;
  }

  Future<void> refresh() async {
    if (state.submitting) return;
    state = state.copyWith(loading: true);
    try {
      final data = await ref.read(managerRepositoryProvider).load(_token);
      if (ref.mounted) state = state.copyWith(data: data, loading: false);
    } catch (error) {
      if (ref.mounted) {
        state = state.copyWith(loading: false, error: _message(error));
      }
    }
  }

  void selectSection(ManagerSection section) => state = state.copyWith(
    section: section,
    query: '',
    resetSelection: true,
    resetStatus: true,
  );
  void search(String query) =>
      state = state.copyWith(query: query, resetSelection: true);
  void filter(String? status) => state = state.copyWith(
    status: status,
    resetStatus: status == null,
    resetSelection: true,
  );
  void select(String id) => state = state.copyWith(selectedId: id);

  Future<bool> _mutate(Future<void> Function(String) action) async {
    if (state.submitting || state.loading) return false;
    state = state.copyWith(submitting: true);
    try {
      final token = _token;
      await action(token);
      if (!ref.mounted) return false;
      // A committed write stays successful even if the subsequent read fails.
      state = state.copyWith(submitting: false);
      await refresh();
      if (ref.mounted) {
        state = state.copyWith(error: state.error, notice: '처리가 완료되었습니다.');
      }
      return true;
    } catch (error) {
      if (ref.mounted) {
        state = state.copyWith(submitting: false, error: _message(error));
      }
      return false;
    }
  }

  Future<bool> createInspection(String requestNumber, String serialCode) {
    if (serialCode.trim().isEmpty || serialCode.trim().length > 50) {
      state = state.copyWith(error: '카탈로그 일련코드를 1~50자로 입력해주세요.');
      return Future.value(false);
    }
    return _mutate(
      (token) => ref
          .read(managerRepositoryProvider)
          .createInspection(token, requestNumber, serialCode.trim()),
    );
  }

  Future<bool> startInspection(String code) => _mutate(
    (token) => ref.read(managerRepositoryProvider).startInspection(token, code),
  );
  Future<bool> completeInspection(String code, String grade, String reason) {
    if (grade.trim().isEmpty ||
        grade.trim().length > 20 ||
        reason.trim().isEmpty ||
        reason.trim().length > 200) {
      state = state.copyWith(error: '등급(1~20자)과 판정 사유(1~200자)를 입력해주세요.');
      return Future.value(false);
    }
    return _mutate(
      (token) => ref
          .read(managerRepositoryProvider)
          .completeInspection(token, code, grade.trim(), reason.trim()),
    );
  }

  String _message(Object error) => error is ManagerException
      ? error.message
      : '관리자 데이터를 처리하지 못했습니다. 다시 시도해주세요.';
}

final managerDashboardVmProvider =
    NotifierProvider.autoDispose<ManagerDashboardVm, ManagerDashboardState>(
      ManagerDashboardVm.new,
    );
