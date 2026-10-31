enum InspectionChoice {
  returnItem('반환'),
  consign('대리판매');

  const InspectionChoice(this.label);
  final String label;
}

class InspectionResult {
  const InspectionResult({
    required this.code,
    required this.requestNumber,
    required this.serialCode,
    required this.status,
    this.grade,
    this.choice,
    this.date,
  });
  final String code, requestNumber, serialCode, status;
  final String? grade, choice, date;
  bool get canChoose => status == '검수완료' && choice == '의사확인대기';
  bool get hasChoice => choice == '반환' || choice == '대리판매';
  factory InspectionResult.fromJson(Map<String, dynamic> json) =>
      InspectionResult(
        code: json['inspect_code'] as String,
        requestNumber: json['inspect_requested_no'] as String,
        serialCode: json['inspect_serial_code'] as String,
        status: json['inspect_status'] as String,
        grade: json['inspect_grade'] as String?,
        choice: json['inspect_user_choice'] as String?,
        date: json['inspect_date'] as String?,
      );
}
