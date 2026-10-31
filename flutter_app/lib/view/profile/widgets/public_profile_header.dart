import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pokem_app/vm/profile/public_profile_vm.dart';
import 'package:pokem_app/view/profile/widgets/profile_avatar.dart';

class PublicProfileHeader extends ConsumerWidget {
  const PublicProfileHeader({super.key, required this.userId, this.onTap});
  final String userId;
  final VoidCallback? onTap;
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final result = ref.watch(publicProfileVmProvider(userId));
    final profile = result.asData?.value;
    final withdrawn = profile?.withdrawn == true;
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: ProfileAvatar(
        size: 48,
        url: withdrawn ? null : profile?.imageUrl,
      ),
      title: Text(
        withdrawn ? '탈퇴한 사용자' : profile?.nickname ?? '판매자 $userId',
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
      ),
      subtitle: profile == null ? null : const Text('판매자'),
      onTap: onTap,
      trailing: result.hasError
          ? IconButton(
              tooltip: '판매자 프로필 다시 불러오기',
              onPressed: () => ref.invalidate(publicProfileVmProvider(userId)),
              icon: const Icon(Icons.refresh),
            )
          : onTap == null
          ? null
          : const Icon(Icons.chevron_right),
    );
  }
}
