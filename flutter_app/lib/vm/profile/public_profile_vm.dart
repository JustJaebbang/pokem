import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pokem_app/core/providers/data_providers.dart';
import 'package:pokem_app/model/profile/public_profile.dart';

class PublicProfileVm extends AsyncNotifier<PublicProfile> {
  PublicProfileVm(this.id);
  final String id;
  @override
  Future<PublicProfile> build() =>
      ref.watch(publicProfileRepositoryProvider).get(id);
}

final publicProfileVmProvider = AsyncNotifierProvider.autoDispose
    .family<PublicProfileVm, PublicProfile, String>(
      PublicProfileVm.new,
      retry: (_, _) => null,
    );
