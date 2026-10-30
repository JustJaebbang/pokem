import 'package:pokem_app/model/inspection/inspection_result.dart';

class InspectionChoiceState {
  const InspectionChoiceState({
    this.busy = false,
    this.uncertain = false,
    this.result,
    this.error,
  });
  final bool busy, uncertain;
  final InspectionResult? result;
  final String? error;
}
