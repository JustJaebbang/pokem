import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pokem_app/core/providers/data_providers.dart';
import 'package:pokem_app/model/manager/manager_dashboard.dart';
import 'package:pokem_app/model/auth/auth_session.dart';
import 'package:pokem_app/model/products/product.dart';
import 'package:pokem_app/model/products/product_photo.dart';
import 'package:pokem_app/vm/auth/login_vm.dart';

enum ManagerSection {
  dashboard,
  products,
  requests,
  inspections,
  consignments,
  proposals,
  procurement,
  returnsDelivery,
  settlements,
  masterData,
  discards,
}

class ManagerDashboardState {
  const ManagerDashboardState({
    this.data,
    this.loading = false,
    this.submitting = false,
    this.error,
    this.notice,
    this.section = ManagerSection.dashboard,
    this.query = '',
    this.status,
    this.selectedId,
    this.page = 0,
  });
  final ManagerDashboard? data;
  final bool loading, submitting;
  final String? error, notice, status, selectedId;
  final int page;
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
    int? page,
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
    page: page ?? this.page,
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
    page: 0,
    resetSelection: true,
    resetStatus: true,
  );
  void search(String query) =>
      state = state.copyWith(query: query, page: 0, resetSelection: true);
  void filter(String? status) => state = state.copyWith(
    status: status,
    page: 0,
    resetStatus: status == null,
    resetSelection: true,
  );
  void select(String id) => state = state.copyWith(selectedId: id);
  void changePage(int page) =>
      state = state.copyWith(page: page < 0 ? 0 : page, resetSelection: true);

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

  Future<bool> createInspectionResult(
    String requestNumber,
    String serialCode,
    String grade,
    String reason,
  ) {
    if (serialCode.trim().isEmpty ||
        serialCode.trim().length > 50 ||
        grade.trim().isEmpty ||
        grade.trim().length > 20 ||
        reason.trim().isEmpty ||
        reason.trim().length > 200) {
      state = state.copyWith(
        error: '일련코드(1~50자), 등급(1~20자), 판정 사유(1~200자)를 입력해주세요.',
      );
      return Future.value(false);
    }
    return _mutate(
      (token) => ref
          .read(managerRepositoryProvider)
          .createInspection(
            token,
            requestNumber,
            serialCode.trim(),
            grade: grade.trim(),
            reason: reason.trim(),
          ),
    );
  }

  Future<bool> approveInspectionRequest(String requestNumber) => _mutate(
    (token) => ref
        .read(managerRepositoryProvider)
        .approveInspectionRequest(token, requestNumber),
  );

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

  Future<bool> createConsignment({
    required String inspectionCode,
    required String title,
    required String image,
    required String contents,
    required String price,
    required String returnCompanyCode,
  }) {
    final amount = int.tryParse(price.trim());
    if (title.trim().isEmpty ||
        title.trim().length > 100 ||
        image.trim().isEmpty ||
        contents.trim().isEmpty ||
        contents.trim().length > 500 ||
        amount == null ||
        amount <= 0 ||
        returnCompanyCode.isEmpty) {
      state = state.copyWith(error: '상품명·이미지·설명·판매가·반환 배송업체를 확인해주세요.');
      return Future.value(false);
    }
    return _mutate(
      (token) => ref.read(managerRepositoryProvider).createConsignment(token, {
        'inspect_inspect_code': inspectionCode,
        'sell_product_title': title.trim(),
        'sell_product_image': image.trim(),
        'sell_product_contents': contents.trim(),
        'sell_product_sell_price': amount,
        'return_delivery_company_code': returnCompanyCode,
      }),
    );
  }

  Future<bool> createConsignmentWithPhoto({
    required String inspectionCode,
    required String title,
    required ProductPhoto photo,
    required String contents,
    required String price,
    required String returnCompanyCode,
  }) {
    final amount = int.tryParse(price.trim());
    if (inspectionCode.isEmpty ||
        title.trim().isEmpty ||
        title.trim().length > 100 ||
        photo.bytes.isEmpty ||
        contents.trim().isEmpty ||
        contents.trim().length > 500 ||
        amount == null ||
        amount <= 0 ||
        returnCompanyCode.isEmpty) {
      state = state.copyWith(error: '검수상품·사진·상품명·설명·판매가·반환 배송업체를 확인해주세요.');
      return Future.value(false);
    }
    return _mutate((token) async {
      // 사진 업로드가 성공한 뒤 서버가 반환한 안전한 경로만 판매상품에 저장한다.
      final imageUrl = await ref
          .read(productPublishRepositoryProvider)
          .uploadPhoto(photo, token);
      await ref.read(managerRepositoryProvider).createConsignment(token, {
        'inspect_inspect_code': inspectionCode,
        'sell_product_title': title.trim(),
        'sell_product_image': imageUrl,
        'sell_product_contents': contents.trim(),
        'sell_product_sell_price': amount,
        'return_delivery_company_code': returnCompanyCode,
      });
    });
  }

  Future<ProductPhoto?> pickConsignmentPhoto() =>
      ref.read(productPhotoPickerProvider).pick();

  Future<bool> createProposal({
    required String name,
    required String contents,
    required String caseCode,
  }) {
    if (name.trim().isEmpty ||
        name.trim().length > 100 ||
        contents.trim().isEmpty ||
        contents.trim().length > 500 ||
        caseCode.isEmpty) {
      state = state.copyWith(error: '품의명·내용·케이스를 확인해주세요.');
      return Future.value(false);
    }
    return _mutate(
      (token) => ref.read(managerRepositoryProvider).createProposal(token, {
        'proposal_name': name.trim(),
        'proposal_contents': contents.trim(),
        'case_case_code': caseCode,
      }),
    );
  }

  Future<bool> createOrder({
    required String proposalNumber,
    required String price,
    required String amount,
    required String companyCode,
  }) {
    final parsedPrice = int.tryParse(price.trim());
    final parsedAmount = int.tryParse(amount.trim());
    if (proposalNumber.isEmpty ||
        companyCode.isEmpty ||
        parsedPrice == null ||
        parsedPrice < 0 ||
        parsedAmount == null ||
        parsedAmount <= 0) {
      state = state.copyWith(error: '승인된 품의·제조업체·발주 금액·수량을 확인해주세요.');
      return Future.value(false);
    }
    return _mutate(
      (token) => ref.read(managerRepositoryProvider).createOrder(token, {
        'proposal_proposal_no': proposalNumber,
        'order_price': parsedPrice,
        'order_amount': parsedAmount,
        'product_company_product_company_code': companyCode,
      }),
    );
  }

  Future<bool> createReceive({
    required String orderNumber,
    required String price,
    required String amount,
  }) {
    final parsedPrice = int.tryParse(price.trim());
    final parsedAmount = int.tryParse(amount.trim());
    final order = state.data?.orders
        .where((item) => item.number == orderNumber)
        .firstOrNull;
    // 화면에서도 잔여 수량을 검사해, 서버의 초과 입고 409를 누르기 전에 안내한다.
    final remaining = order == null ? 0 : state.data!.remainingAmount(order);
    if (orderNumber.isEmpty ||
        parsedPrice == null ||
        parsedPrice < 0 ||
        parsedAmount == null ||
        parsedAmount <= 0 ||
        parsedAmount > remaining) {
      state = state.copyWith(error: '입고 금액과 잔여 수량($remaining개)을 확인해주세요.');
      return Future.value(false);
    }
    return _mutate(
      (token) => ref.read(managerRepositoryProvider).createReceive(token, {
        'order_order_no': orderNumber,
        'receive_price': parsedPrice,
        'receive_amount': parsedAmount,
      }),
    );
  }

  Future<bool> assignReturn(String number) => _mutate(
    (token) => ref.read(managerRepositoryProvider).assignReturn(token, number),
  );

  Future<bool> createReturnDelivery(String returnNumber, String companyCode) {
    if (returnNumber.isEmpty || companyCode.isEmpty) {
      state = state.copyWith(error: '반환 건과 배송업체를 선택해주세요.');
      return Future.value(false);
    }
    return _mutate(
      (token) => ref.read(managerRepositoryProvider).createDelivery(token, {
        'return_no': returnNumber,
        'delivery_company_delivery_company_code': companyCode,
      }),
    );
  }

  Future<bool> createPurchaseDelivery(String purchaseCode, String companyCode) {
    if (purchaseCode.trim().isEmpty || companyCode.isEmpty) {
      state = state.copyWith(error: '구매번호와 배송업체를 입력해주세요.');
      return Future.value(false);
    }
    return _mutate(
      (token) => ref.read(managerRepositoryProvider).createDelivery(token, {
        'purchase_item_code': purchaseCode.trim(),
        'delivery_company_delivery_company_code': companyCode,
      }),
    );
  }

  Future<bool> updateDeliveryStatus(String number, String status) => _mutate(
    (token) => ref
        .read(managerRepositoryProvider)
        .updateDeliveryStatus(token, number, status),
  );

  Future<bool> setConsignmentReturnCompany(String code, String company) =>
      _mutate(
        (token) => ref
            .read(managerRepositoryProvider)
            .setConsignmentReturnCompany(token, code, company),
      );

  Future<bool> updatePayStatus(String number, String status) => _mutate(
    (token) => ref
        .read(managerRepositoryProvider)
        .updatePayStatus(token, number, status.trim()),
  );

  Future<bool> createReceipt({
    required String payNumber,
    required String productCode,
    required String amount,
  }) {
    final parsed = int.tryParse(amount.trim());
    if (payNumber.isEmpty ||
        productCode.trim().isEmpty ||
        parsed == null ||
        parsed <= 0) {
      state = state.copyWith(error: '결제, 상품코드, 접수 수량을 확인해주세요.');
      return Future.value(false);
    }
    return _mutate(
      (token) => ref.read(managerRepositoryProvider).createReceipt(token, {
        'pay_pay_no': payNumber,
        'receipt_amount': parsed,
        'sell_product_sell_product_code': productCode.trim(),
      }),
    );
  }

  Future<bool> createRefund(String payNumber) => _mutate(
    (token) =>
        ref.read(managerRepositoryProvider).createRefund(token, payNumber),
  );

  Future<bool> createCase({
    required String serial,
    required String price,
    required String stock,
  }) {
    final parsedPrice = int.tryParse(price.trim());
    final parsedStock = int.tryParse(stock.trim());
    if (serial.trim().isEmpty ||
        parsedPrice == null ||
        parsedPrice < 0 ||
        parsedStock == null ||
        parsedStock < 0) {
      state = state.copyWith(error: '케이스 일련번호, 가격, 재고를 확인해주세요.');
      return Future.value(false);
    }
    return _mutate(
      (token) => ref.read(managerRepositoryProvider).createCase(token, {
        'case_serial_no': serial.trim(),
        'case_price': parsedPrice,
        'case_stock': parsedStock,
      }),
    );
  }

  Future<bool> createProductCompany(String code, String name) {
    if (code.trim().isEmpty || name.trim().isEmpty) {
      state = state.copyWith(error: '제조업체 코드와 업체명을 입력해주세요.');
      return Future.value(false);
    }
    return _mutate(
      (token) =>
          ref.read(managerRepositoryProvider).createProductCompany(token, {
            'product_company_code': code.trim(),
            'product_company_name': name.trim(),
          }),
    );
  }

  Future<bool> createDeliveryCompany(String code, String name) {
    if (code.trim().isEmpty || name.trim().isEmpty) {
      state = state.copyWith(error: '배송업체 코드와 업체명을 입력해주세요.');
      return Future.value(false);
    }
    return _mutate(
      (token) =>
          ref.read(managerRepositoryProvider).createDeliveryCompany(token, {
            'delivery_company_code': code.trim(),
            'delivery_company_name': name.trim(),
          }),
    );
  }

  Future<bool> createDiscard(String productCode) {
    if (productCode.trim().isEmpty) {
      state = state.copyWith(error: '폐기할 판매상품 코드를 입력해주세요.');
      return Future.value(false);
    }
    return _mutate(
      (token) => ref
          .read(managerRepositoryProvider)
          .createDiscard(token, productCode.trim()),
    );
  }

  Future<bool> updateCase(String code, String price, String stock) {
    final parsedPrice = int.tryParse(price.trim());
    final parsedStock = int.tryParse(stock.trim());
    if (parsedPrice == null ||
        parsedPrice < 0 ||
        parsedStock == null ||
        parsedStock < 0) {
      state = state.copyWith(error: '가격과 재고를 0 이상의 숫자로 입력해주세요.');
      return Future.value(false);
    }
    return _mutate(
      (token) => ref.read(managerRepositoryProvider).updateCase(token, code, {
        'case_price': parsedPrice,
        'case_stock': parsedStock,
      }),
    );
  }

  Future<bool> updateCompany(
    String code,
    String name, {
    required bool delivery,
  }) {
    if (name.trim().isEmpty) return Future.value(false);
    return _mutate(
      (token) => delivery
          ? ref
                .read(managerRepositoryProvider)
                .updateDeliveryCompany(token, code, name.trim())
          : ref
                .read(managerRepositoryProvider)
                .updateProductCompany(token, code, name.trim()),
    );
  }

  Future<bool> cancelReceive(String number) => _mutate(
    (token) => ref.read(managerRepositoryProvider).cancelReceive(token, number),
  );
  Future<bool> cancelReceipt(String number) => _mutate(
    (token) => ref.read(managerRepositoryProvider).cancelReceipt(token, number),
  );

  String _message(Object error) => switch (error) {
    ManagerException() => error.message,
    ProductException() => error.message,
    _ => '관리자 데이터를 처리하지 못했습니다. 다시 시도해주세요.',
  };
}

final managerDashboardVmProvider =
    NotifierProvider.autoDispose<ManagerDashboardVm, ManagerDashboardState>(
      ManagerDashboardVm.new,
    );
