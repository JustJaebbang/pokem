class ReturnItem {
  const ReturnItem({
    required this.number,
    required this.inspectCode,
    this.managerId,
  });
  final String number, inspectCode;
  final String? managerId;
  factory ReturnItem.fromJson(Map<String, dynamic> json) => ReturnItem(
    number: json['return_no'] as String,
    inspectCode: json['inspect_inspect_code'] as String,
    managerId: json['manager_manager_id'] as String?,
  );
}
