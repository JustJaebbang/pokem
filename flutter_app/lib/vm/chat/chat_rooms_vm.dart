import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pokem_app/core/providers/data_providers.dart';
import 'package:pokem_app/model/chat/chat_models.dart';
import 'package:pokem_app/vm/auth/login_vm.dart';
import 'package:pokem_app/vm/chat/state/chat_states.dart';

class ChatRoomsVm extends Notifier<ChatRoomsState> {
  @override
  ChatRoomsState build() {
    ref.watch(loginVmProvider.select((s) => s.session?.account.id));
    Future.microtask(() => _load(false));
    return const ChatRoomsState(loading: true);
  }

  Future<void> refresh() async {
    if (!state.loading) await _load(false);
  }

  Future<void> loadMore() async {
    if (!state.loading && state.hasMore) await _load(true);
  }

  Future<void> _load(bool more) async {
    if (!ref.mounted) return;
    final session = ref.read(authRepositoryProvider).session;
    if (session == null) {
      await ref.read(loginVmProvider.notifier).logout(expired: true);
      return;
    }
    final old = more ? state.rooms : <ChatRoom>[];
    state = ChatRoomsState(
      loading: true,
      rooms: state.rooms,
      hasMore: state.hasMore,
    );
    try {
      final rooms = await ref
          .read(chatRepositoryProvider)
          .rooms(session.token, old.length);
      if (!ref.mounted ||
          ref.read(authRepositoryProvider).session?.account.id !=
              session.account.id) {
        return;
      }
      state = ChatRoomsState(
        rooms: {
          for (final r in [...old, ...rooms]) r.id: r,
        }.values.toList(),
        hasMore: rooms.length == 50,
      );
    } catch (e) {
      if (ref.mounted) {
        state = ChatRoomsState(
          rooms: state.rooms,
          hasMore: state.hasMore,
          error: e is ChatException ? e.message : '채팅방을 불러오지 못했습니다.',
        );
        if (e is ChatException && e.status == 401) {
          await ref.read(loginVmProvider.notifier).logout(expired: true);
        }
      }
    }
  }
}

final chatRoomsVmProvider =
    NotifierProvider.autoDispose<ChatRoomsVm, ChatRoomsState>(ChatRoomsVm.new);
