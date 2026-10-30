String formatPurchaseTime(String? value) {
  final parsed = value == null ? null : DateTime.tryParse(value);
  if (parsed == null) return '구매 시간 확인 불가';
  final local = parsed.toLocal();
  String two(int number) => number.toString().padLeft(2, '0');
  return '${local.year}.${two(local.month)}.${two(local.day)} ${two(local.hour)}:${two(local.minute)}';
}
