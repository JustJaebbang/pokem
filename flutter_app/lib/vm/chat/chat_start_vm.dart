import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pokem_app/core/providers/data_providers.dart';
import 'package:pokem_app/model/chat/chat_models.dart';
import 'package:pokem_app/vm/auth/login_vm.dart';
import 'package:pokem_app/vm/chat/chat_rooms_vm.dart';
import 'package:pokem_app/vm/chat/state/chat_states.dart';

class ChatStartVm extends Notifier<ChatStartState> {
  @override
  ChatStartState build() => const ChatStartState();
  Future<ChatRoom?> open(String code) async {
    if (state.opening) return null;
    final session = ref.read(authRepositoryProvider).session;
    if (session == null) {
      await ref.read(loginVmProvider.notifier).logout(expired: true);
      return null;
    }
    state = const ChatStartState(opening: true);
    try {
      final room = await ref
          .read(chatRepositoryProvider)
          .open(code, session.token);
      if (!ref.mounted) return null;
      ref.invalidate(chatRoomsVmProvider);
      state = const ChatStartState();
      return room;
    } catch (e) {
      if (ref.mounted) {
        state = ChatStartState(
          error: e is ChatException ? e.message : '채팅방을 열지 못했습니다.',
        );
        if (e is ChatException && e.status == 401) {
          await ref.read(loginVmProvider.notifier).logout(expired: true);
        }
      }
      return null;
    }
  }
}

final chatStartVmProvider =
    NotifierProvider.autoDispose<ChatStartVm, ChatStartState>(ChatStartVm.new);
