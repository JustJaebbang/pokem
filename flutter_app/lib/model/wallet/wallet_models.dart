enum MoneyAction {
  recharge('충전', 'recharge'),
  exchange('환전', 'exchange');

  const MoneyAction(this.label, this.path);
  final String label;
  final String path;
}

class MoneyRecord {
  const MoneyRecord({
    required this.action,
    required this.seq,
    required this.amount,
    this.date,
    this.account,
  });
  final MoneyAction action;
  final int seq;
  final int amount;
  final String? date;
  final String? account;
  factory MoneyRecord.fromJson(MoneyAction action, Map<String, dynamic> json) {
    final prefix = action.path;
    return MoneyRecord(
      action: action,
      seq: json['${prefix}_seq'] as int,
      amount: json['${prefix}_price'] as int,
      date: json['${prefix}_date'] as String?,
      account: json['${prefix}_account'] as String?,
    );
  }
}

class MoneyReceipt {
  const MoneyReceipt(this.record, this.balance);
  final MoneyRecord record;
  final int balance;
}

class WalletSnapshot {
  const WalletSnapshot(this.balance, this.records);
  final int balance;
  final List<MoneyRecord> records;
}

class WalletException implements Exception {
  const WalletException(this.message, {this.status, this.uncertain = false});
  final String message;
  final int? status;
  final bool uncertain;
  @override
  String toString() => message;
}
