String formatWon(int amount) {
  final digits = amount.abs().toString().replaceAllMapped(
    RegExp(r'\B(?=(\d{3})+(?!\d))'),
    (_) => ',',
  );
  return '${amount < 0 ? '-' : ''}$digits원';
}
