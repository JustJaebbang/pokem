import 'package:flutter/material.dart';

import 'cybermoney_pay.dart';
import 'wallet_transactions.dart';
import 'user_account.dart';
import 'purchase_item_history.dart';
import 'review_page.dart';

class MyInfoPage extends StatefulWidget {
  const MyInfoPage(
      {super.key,
      required this.account,
      required this.role,
      required this.token,
      this.onLogout});

  final Map<String, dynamic> account;
  final String role;
  final String token;
  final VoidCallback? onLogout;

  @override
  State<MyInfoPage> createState() => _MyInfoPageState();
}

class _MyInfoPageState extends State<MyInfoPage> {
  late Map<String, dynamic> _account;

  @override
  void initState() {
    super.initState();
    _account = Map<String, dynamic>.from(widget.account);
  }

  Map<String, dynamic> get account => _account;
  String get role => widget.role;
  String get token => widget.token;
  VoidCallback? get onLogout => widget.onLogout;

  @override
  Widget build(BuildContext context) {
    final name = (account['user_nickname'] ??
            account['manager_name'] ??
            account['director_name'] ??
            '회원')
        .toString();
    final id = (account['user_id'] ??
            account['manager_id'] ??
            account['director_id'] ??
            '')
        .toString();
    return ListView(
      padding: const EdgeInsets.all(22),
      children: [
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: const Color(0xFFEAECF2))),
          child: Row(children: [
            const CircleAvatar(
                radius: 26,
                backgroundColor: Color(0xFFECEAFF),
                child: Icon(Icons.person_rounded, color: Color(0xFF6658E8))),
            const SizedBox(width: 14),
            Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(name,
                  style: const TextStyle(
                      fontSize: 17, fontWeight: FontWeight.w700)),
              const SizedBox(height: 4),
              Text(id, style: const TextStyle(color: Color(0xFF858B9A)))
            ]),
          ]),
        ),
        const SizedBox(height: 12),
        _InfoRow(
            label: '계정 유형',
            value: switch (role) {
              'manager' => '관리자',
              'director' => '운영자',
              _ => '일반 회원',
            }),
        if (account['user_email'] != null)
          _InfoRow(label: '이메일', value: account['user_email'].toString()),
        if (account['user_money'] != null)
          _InfoRow(label: '보유 머니', value: '${account['user_money']}원'),
        if (role == 'user') ...[
          const SizedBox(height: 14),
          _WalletMenuTile(
            icon: Icons.shopping_bag_outlined,
            title: '구매 내역',
            subtitle: '구매 코드와 거래 상태 확인, 구매 확정',
            onTap: () => Navigator.of(context).push<void>(
              MaterialPageRoute<void>(
                builder: (_) => PurchaseItemHistoryPage(token: token),
              ),
            ),
          ),
          const SizedBox(height: 9),
          _WalletMenuTile(
            icon: Icons.rate_review_outlined,
            title: '구매 리뷰',
            subtitle: '구매 확정 상품 리뷰 작성 및 내 리뷰 확인',
            onTap: () => Navigator.of(context).push<void>(
              MaterialPageRoute<void>(
                builder: (_) => ReviewPage(token: token, userId: id),
              ),
            ),
          ),
          const SizedBox(height: 9),
          _WalletMenuTile(
            icon: Icons.manage_accounts_outlined,
            title: '회원 정보 관리',
            subtitle: '연락처 수정 및 회원 탈퇴',
            onTap: () => Navigator.of(context).push<void>(
              MaterialPageRoute<void>(
                builder: (_) => UserAccountPage(
                  account: account,
                  token: token,
                  onLogout: onLogout,
                ),
              ),
            ),
          ),
          const SizedBox(height: 9),
          _WalletMenuTile(
            icon: Icons.add_card_rounded,
            title: '사이버머니 충전',
            subtitle: '충전 요청 및 내역 확인',
            onTap: () => Navigator.of(context).push<void>(
              MaterialPageRoute<void>(
                builder: (_) => RechargePage(
                  token: token,
                  userId: id,
                  onBalanceChanged: (balance) => setState(() {
                    _account = {..._account, 'user_money': balance};
                  }),
                ),
              ),
            ),
          ),
          const SizedBox(height: 9),
          _WalletMenuTile(
            icon: Icons.currency_exchange_rounded,
            title: '사이버머니 환전',
            subtitle: '환전 요청 및 내역 확인',
            onTap: () => Navigator.of(context).push<void>(
              MaterialPageRoute<void>(
                builder: (_) => ExchangePage(token: token, userId: id),
              ),
            ),
          ),
          const SizedBox(height: 9),
          Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(15),
              border: Border.all(color: const Color(0xFFEAECF2)),
            ),
            child: ListTile(
              leading: const CircleAvatar(
                backgroundColor: Color(0xFFECEAFF),
                child:
                    Icon(Icons.receipt_long_rounded, color: Color(0xFF6658E8)),
              ),
              title: const Text('결제 내역',
                  style: TextStyle(fontWeight: FontWeight.w700)),
              subtitle: const Text('사이버머니 결제 기록 확인'),
              trailing: const Icon(Icons.chevron_right_rounded),
              onTap: () => Navigator.of(context).push<void>(
                MaterialPageRoute<void>(
                  builder: (_) => CybermoneyPayPage(token: token),
                ),
              ),
            ),
          ),
        ],
        if (onLogout != null) ...[
          const SizedBox(height: 18),
          OutlinedButton.icon(
              onPressed: onLogout,
              icon: const Icon(Icons.logout_rounded),
              label: const Text('로그아웃')),
        ],
      ],
    );
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({required this.label, required this.value});
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) => Container(
        margin: const EdgeInsets.only(top: 10),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 15),
        decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(15),
            border: Border.all(color: const Color(0xFFEAECF2))),
        child:
            Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          Text(label, style: const TextStyle(color: Color(0xFF858B9A))),
          Flexible(
              child: Text(value,
                  textAlign: TextAlign.right,
                  style: const TextStyle(fontWeight: FontWeight.w600)))
        ]),
      );
}

class _WalletMenuTile extends StatelessWidget {
  const _WalletMenuTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(15),
          border: Border.all(color: const Color(0xFFEAECF2)),
        ),
        child: ListTile(
          leading: CircleAvatar(
            backgroundColor: const Color(0xFFECEAFF),
            child: Icon(icon, color: const Color(0xFF6658E8)),
          ),
          title: Text(title, style: const TextStyle(fontWeight: FontWeight.w700)),
          subtitle: Text(subtitle),
          trailing: const Icon(Icons.chevron_right_rounded),
          onTap: onTap,
        ),
      );
}
