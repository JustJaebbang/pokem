import 'package:pokem_app/view/profile/widgets/profile_avatar.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pokem_app/vm/chat/chat_room_vm.dart';

class ChatRoomView extends ConsumerStatefulWidget {
  const ChatRoomView({super.key, required this.roomId});
  final String roomId;
  @override
  ConsumerState<ChatRoomView> createState() => _ChatRoomViewState();
}

class _ChatRoomViewState extends ConsumerState<ChatRoomView> {
  final _text = TextEditingController();
  @override
  void dispose() {
    _text.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(chatRoomVmProvider(widget.roomId));
    ref.listen(
      chatRoomVmProvider(widget.roomId).select((s) => s.sentRevision),
      (previous, next) {
        if (previous != null && next > previous) _text.clear();
      },
    );
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            ProfileAvatar(size: 36, url: state.room?.displayOtherImage),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    state.room?.displayOther(state.userId) ?? '채팅',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  if (state.room != null)
                    Text(
                      state.room!.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodySmall,
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
      body: SafeArea(
        child: Column(
          children: [
            if (state.connecting) const LinearProgressIndicator(),
            if (state.error != null)
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 8,
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Semantics(
                        liveRegion: true,
                        child: Text(
                          state.error!,
                          style: TextStyle(color: theme.colorScheme.error),
                        ),
                      ),
                    ),
                    if (!state.closed && !state.ready)
                      TextButton(
                        onPressed: () => ref
                            .read(chatRoomVmProvider(widget.roomId).notifier)
                            .reconnect(),
                        child: const Text('다시 연결'),
                      ),
                  ],
                ),
              ),
            if (state.closed)
              const Padding(
                padding: EdgeInsets.all(12),
                child: Text('종료된 대화입니다.'),
              ),
            Expanded(
              child: ListView.builder(
                reverse: true,
                padding: const EdgeInsets.all(16),
                itemCount: state.messages.length,
                itemBuilder: (context, index) {
                  final message =
                      state.messages[state.messages.length - 1 - index];
                  final mine = message.userId == state.userId;
                  final time = message.time.toLocal();
                  final earlier = state.messages.length - 2 - index;
                  final previous = earlier < 0
                      ? null
                      : state.messages[earlier].time.toLocal();
                  final showDate =
                      previous == null ||
                      previous.year != time.year ||
                      previous.month != time.month ||
                      previous.day != time.day;
                  return Column(
                    children: [
                      if (showDate)
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          child: Text(
                            '${time.year}년 ${time.month}월 ${time.day}일',
                            style: theme.textTheme.labelSmall,
                          ),
                        ),
                      Align(
                        alignment: mine
                            ? Alignment.centerRight
                            : Alignment.centerLeft,
                        child: ConstrainedBox(
                          constraints: BoxConstraints(
                            maxWidth: MediaQuery.sizeOf(context).width * .78,
                          ),
                          child: Column(
                            crossAxisAlignment: mine
                                ? CrossAxisAlignment.end
                                : CrossAxisAlignment.start,
                            children: [
                              Container(
                                key: ValueKey('message-${message.seq}'),
                                margin: const EdgeInsets.only(bottom: 4),
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 14,
                                  vertical: 10,
                                ),
                                decoration: BoxDecoration(
                                  color: mine
                                      ? theme.colorScheme.primary
                                      : theme
                                            .colorScheme
                                            .surfaceContainerHighest,
                                  borderRadius: BorderRadius.circular(16),
                                ),
                                child: Text(
                                  message.text,
                                  style: TextStyle(
                                    color: mine
                                        ? theme.colorScheme.onPrimary
                                        : theme.colorScheme.onSurface,
                                  ),
                                ),
                              ),
                              Text(
                                '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}',
                                style: theme.textTheme.labelSmall,
                              ),
                              const SizedBox(height: 12),
                            ],
                          ),
                        ),
                      ),
                    ],
                  );
                },
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Expanded(
                    child: TextField(
                      key: const Key('chatComposer'),
                      controller: _text,
                      enabled: !state.closed && !state.sending,
                      minLines: 1,
                      maxLines: 4,
                      maxLength: 500,
                      decoration: const InputDecoration(
                        hintText: '메시지 입력',
                        counterText: '',
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton.filled(
                    key: const Key('sendChat'),
                    tooltip: '전송',
                    onPressed: state.canSend
                        ? () => ref
                              .read(chatRoomVmProvider(widget.roomId).notifier)
                              .send(_text.text)
                        : null,
                    icon: state.sending
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.arrow_upward),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
