import 'package:pokem_app/model/inspection/inspection_request.dart';

class InspectionCreateState {
  const InspectionCreateState({
    this.submitting = false,
    this.uncertain = false,
    this.request,
    this.error,
  });
  final bool submitting, uncertain;
  final InspectionRequest? request;
  final String? error;
  bool get locked => submitting || uncertain || request != null;
}
