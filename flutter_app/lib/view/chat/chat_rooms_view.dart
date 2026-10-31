import 'package:pokem_app/view/profile/widgets/profile_avatar.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pokem_app/vm/auth/login_vm.dart';
import 'package:pokem_app/vm/chat/chat_rooms_vm.dart';
import 'package:pokem_app/view/chat/chat_room_view.dart';

class ChatRoomsView extends ConsumerWidget {
  const ChatRoomsView({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(chatRoomsVmProvider);
    final userId =
        ref.watch(loginVmProvider.select((s) => s.session?.account.id)) ?? '';
    return RefreshIndicator(
      onRefresh: () => ref.read(chatRoomsVmProvider.notifier).refresh(),
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        children: [
          if (state.error != null)
            Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                children: [
                  Text(state.error!, textAlign: TextAlign.center),
                  TextButton(
                    onPressed: () =>
                        ref.read(chatRoomsVmProvider.notifier).refresh(),
                    child: const Text('다시 시도'),
                  ),
                ],
              ),
            ),
          if (state.loading)
            const Padding(
              padding: EdgeInsets.all(24),
              child: Center(child: CircularProgressIndicator()),
            ),
          if (!state.loading && state.error == null && state.rooms.isEmpty)
            const Padding(
              padding: EdgeInsets.all(40),
              child: Text('아직 대화가 없습니다.', textAlign: TextAlign.center),
            ),
          for (final room in state.rooms)
            ListTile(
              key: ValueKey('room-${room.id}'),
              leading: ProfileAvatar(size: 48, url: room.displayOtherImage),
              title: Text(
                room.displayOther(userId),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              subtitle: Text(
                room.name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              trailing: room.isClosed
                  ? const Text('종료')
                  : const Icon(Icons.chevron_right),
              onTap: () async {
                await Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => ChatRoomView(roomId: room.id),
                  ),
                );
                if (context.mounted) {
                  ref.read(chatRoomsVmProvider.notifier).refresh();
                }
              },
            ),
          if (state.hasMore)
            Padding(
              padding: const EdgeInsets.all(12),
              child: TextButton(
                onPressed: state.loading
                    ? null
                    : () => ref.read(chatRoomsVmProvider.notifier).loadMore(),
                child: const Text('더 보기'),
              ),
            ),
        ],
      ),
    );
  }
}
