import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pokem_app/vm/profile/profile_summary_vm.dart';
import 'package:pokem_app/view/profile/profile_view.dart';
import 'package:pokem_app/view/profile/widgets/profile_avatar.dart';

class MyProfileAvatar extends ConsumerWidget {
  const MyProfileAvatar({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profile = ref.watch(profileSummaryVmProvider).asData?.value;
    return Center(
      child: Semantics(
        button: true,
        label: '프로필 사진 변경',
        child: InkWell(
          customBorder: const CircleBorder(),
          onTap: () => Navigator.of(
            context,
          ).push(MaterialPageRoute<void>(builder: (_) => const ProfileView())),
          child: ProfileAvatar(url: profile?.imageUrl),
        ),
      ),
    );
  }
}
