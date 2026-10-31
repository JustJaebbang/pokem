class PendingActions {
  const PendingActions({
    required this.fees,
    required this.choices,
    required this.cancellations,
    this.feeRequest,
    this.choiceRequest,
  });
  final int fees, choices, cancellations;
  final String? feeRequest, choiceRequest;
  bool get isEmpty => fees == 0 && choices == 0 && cancellations == 0;
  factory PendingActions.fromJson(Map<String, dynamic> j) {
    final result = PendingActions(
      fees: j['fee_count'] as int,
      choices: j['choice_count'] as int,
      cancellations: j['cancel_count'] as int,
      feeRequest: j['fee_request_no'] as String?,
      choiceRequest: j['choice_request_no'] as String?,
    );
    if (result.fees < 0 ||
        result.choices < 0 ||
        result.cancellations < 0 ||
        result.fees > 0 && (result.feeRequest?.isNotEmpty != true) ||
        result.choices > 0 && (result.choiceRequest?.isNotEmpty != true)) {
      throw const FormatException('Invalid pending actions');
    }
    return result;
  }
}

class PendingActionsException implements Exception {
  const PendingActionsException(this.message, {this.status});
  final String message;
  final int? status;
}
