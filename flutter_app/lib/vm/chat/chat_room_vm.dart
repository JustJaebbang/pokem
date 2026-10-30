import 'dart:async';
import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pokem_app/core/providers/data_providers.dart';
import 'package:pokem_app/model/chat/chat_models.dart';
import 'package:pokem_app/service/chat/chat_socket_service.dart';
import 'package:pokem_app/vm/auth/login_vm.dart';
import 'package:pokem_app/vm/chat/state/chat_states.dart';

class ChatRoomVm extends Notifier<ChatRoomState> {
  ChatRoomVm(this.roomId);
  final String roomId;
  ChatConnection? _connection;
  StreamSubscription<Object?>? _subscription;
  Timer? _retryTimer, _readyTimer, _ackTimer;
  int _epoch = 0,
      _version = 0,
      _attempt = 0,
      _historyCursor = 0,
      _pendingAfter = 0;
  bool _stopped = false;
  int? _connectingEpoch, _startingEpoch;
  String? _pendingText;
  bool _valid(int epoch, int version) =>
      ref.mounted && epoch == _epoch && version == _version;

  @override
  ChatRoomState build() {
    final userId =
        ref.watch(loginVmProvider.select((s) => s.session?.account.id)) ?? '';
    final epoch = ++_epoch;
    _stopped = false;
    _historyCursor = 0;
    _pendingText = null;
    ref.onDispose(() {
      _stopped = true;
      _epoch++;
      _retryTimer?.cancel();
      _readyTimer?.cancel();
      _ackTimer?.cancel();
      unawaited(_drop());
    });
    Future.microtask(() => _start(epoch));
    return ChatRoomState(userId: userId);
  }

  Future<void> _drop() async {
    _readyTimer?.cancel();
    final sub = _subscription;
    _subscription = null;
    final connection = _connection;
    _connection = null;
    try {
      await sub?.cancel();
    } catch (_) {}
    try {
      await connection?.close();
    } catch (_) {}
  }

  Future<void> _start(int epoch) async {
    if (!ref.mounted || epoch != _epoch || _startingEpoch == epoch) return;
    final session = ref.read(authRepositoryProvider).session;
    if (session == null) {
      await ref.read(loginVmProvider.notifier).logout(expired: true);
      return;
    }
    _startingEpoch = epoch;
    state = state.copyWith(connecting: true, ready: false);
    try {
      final room = await ref
          .read(chatRepositoryProvider)
          .room(roomId, session.token);
      if (!ref.mounted || epoch != _epoch) return;
      state = state.copyWith(room: room, closed: room.isClosed);
      if (room.isClosed) {
        await _recover(epoch, _version);
        return;
      }
      await _connect(epoch);
    } catch (e) {
      await _fail(e, epoch);
    } finally {
      if (_startingEpoch == epoch) _startingEpoch = null;
    }
  }

  Future<void> _connect(int epoch) async {
    if (!ref.mounted ||
        epoch != _epoch ||
        _stopped ||
        _connectingEpoch == epoch) {
      return;
    }
    _connectingEpoch = epoch;
    final version = ++_version;
    try {
      await _drop();
      if (!_valid(epoch, version)) return;
      final session = ref.read(authRepositoryProvider).session;
      if (session == null) {
        await ref.read(loginVmProvider.notifier).logout(expired: true);
        return;
      }
      state = state.copyWith(connecting: true, ready: false);
      final connection = await ref
          .read(chatRepositoryProvider)
          .connect(roomId, session.token);
      if (!_valid(epoch, version)) {
        await connection.close();
        return;
      }
      _connection = connection;
      _subscription = connection.events.listen(
        (event) => _event(event, epoch, version),
        onError: (Object error, StackTrace stack) => _lost(epoch, version),
        onDone: () =>
            _lost(epoch, version, fatal: connection.closeCode == 1008),
      );
      _readyTimer = Timer(
        const Duration(seconds: 10),
        () => _lost(epoch, version),
      );
    } catch (e) {
      if (_valid(epoch, version)) _lost(epoch, version);
    } finally {
      if (_connectingEpoch == epoch) _connectingEpoch = null;
    }
  }

  Future<void> _event(Object? raw, int epoch, int version) async {
    if (!_valid(epoch, version)) return;
    try {
      final j = jsonDecode(raw as String) as Map<String, dynamic>;
      switch (j['type']) {
        case 'ready':
          if (j['room_id'] != roomId || j['user_id'] != state.userId) {
            throw const ChatException('채팅 연결 정보를 확인해주세요.', status: 403);
          }
          _readyTimer?.cancel();
          await _recover(epoch, version);
        case 'message':
          _merge([ChatMessage.fromJson(j['data'] as Map<String, dynamic>)]);
        case 'error':
          final status = j['status'] as int?;
          if ([401, 403, 404].contains(status)) {
            await _fail(
              ChatException(
                j['detail'] as String? ?? '채팅 권한을 확인해주세요.',
                status: status,
              ),
              epoch,
            );
            return;
          }
          _ackTimer?.cancel();
          _pendingText = null;
          state = state.copyWith(
            sending: false,
            closed: status == 409 ? true : null,
            error: j['detail'] as String? ?? '메시지를 보내지 못했습니다.',
          );
          if (status == 409) {
            _stopped = true;
            await _drop();
          }
      }
    } catch (e) {
      await _fail(
        e is ChatException
            ? e
            : const ChatException('메시지를 읽지 못했습니다. 다시 연결해주세요.'),
        epoch,
      );
    }
  }

  void _merge(List<ChatMessage> incoming) {
    final bySeq = {for (final m in state.messages) m.seq: m};
    var acknowledged = false;
    for (final m in incoming) {
      if (m.roomId != roomId || m.seq <= 0) continue;
      bySeq[m.seq] = m;
      if (_pendingText != null &&
          m.seq > _pendingAfter &&
          m.userId == state.userId &&
          m.text == _pendingText) {
        acknowledged = true;
      }
    }
    if (acknowledged) {
      _pendingText = null;
      _ackTimer?.cancel();
    }
    final messages = bySeq.values.toList()
      ..sort((a, b) => a.seq.compareTo(b.seq));
    state = state.copyWith(
      messages: messages,
      sending: acknowledged ? false : null,
      sentRevision: acknowledged ? state.sentRevision + 1 : null,
    );
  }

  Future<void> _recover(int epoch, int version) async {
    final session = ref.read(authRepositoryProvider).session;
    if (session == null) {
      await ref.read(loginVmProvider.notifier).logout(expired: true);
      return;
    }
    final repository = ref.read(chatRepositoryProvider);
    var cursor = _historyCursor;
    while (_valid(epoch, version)) {
      final batch = await repository.messages(roomId, session.token, cursor);
      if (!_valid(epoch, version)) return;
      if (batch.any((m) => m.roomId != roomId || m.seq <= cursor)) {
        throw const ChatException('대화 이력을 확인하지 못했습니다. 다시 연결해주세요.');
      }
      _merge(batch);
      if (batch.isNotEmpty) {
        cursor = batch.map((m) => m.seq).reduce((a, b) => a > b ? a : b);
        _historyCursor = cursor;
      }
      if (batch.length < 100) break;
    }
    if (!_valid(epoch, version)) return;
    final unresolved = _pendingText != null;
    _pendingText = null;
    _ackTimer?.cancel();
    _attempt = 0;
    state = state.copyWith(
      connecting: false,
      ready: !state.closed,
      sending: false,
      error: unresolved ? '전송 결과를 확인한 뒤 다시 보내주세요.' : null,
      clearError: !unresolved,
    );
  }

  void _lost(int epoch, int version, {bool fatal = false}) {
    if (!_valid(epoch, version) || _stopped) return;
    _version++;
    _ackTimer?.cancel();
    unawaited(_drop());
    state = state.copyWith(
      ready: false,
      connecting: !fatal,
      sending: false,
      error: fatal ? '채팅에 연결할 수 없습니다. 권한을 확인해주세요.' : '연결이 끊겼습니다. 다시 연결하고 있습니다.',
    );
    if (fatal) {
      _stopped = true;
      return;
    }
    _retryTimer?.cancel();
    final seconds = [2, 4, 8, 16, 30][_attempt.clamp(0, 4)];
    _attempt++;
    _retryTimer = Timer(Duration(seconds: seconds), () => _connect(epoch));
  }

  Future<void> _fail(Object error, int epoch) async {
    if (!ref.mounted || epoch != _epoch) return;
    _stopped = true;
    _version++;
    _retryTimer?.cancel();
    _ackTimer?.cancel();
    state = state.copyWith(
      connecting: false,
      ready: false,
      sending: false,
      error: error is ChatException ? error.message : '채팅에 연결하지 못했습니다.',
    );
    await _drop();
    if (ref.mounted && error is ChatException && error.status == 401) {
      await ref.read(loginVmProvider.notifier).logout(expired: true);
    }
  }

  Future<void> reconnect() async {
    if (_connectingEpoch == _epoch) return;
    _retryTimer?.cancel();
    _stopped = false;
    _attempt = 0;
    await _start(_epoch);
  }

  String? validateMessage(String text) {
    if (text.trim().isEmpty) return '메시지를 입력해주세요.';
    if (text.trim().runes.length > 500) return '메시지는 500자까지 보낼 수 있습니다.';
    return null;
  }

  void send(String text) {
    if (!state.canSend) return;
    final error = validateMessage(text);
    if (error != null) {
      state = state.copyWith(error: error);
      return;
    }
    _pendingText = text.trim();
    _pendingAfter = state.messages.isEmpty ? 0 : state.messages.last.seq;
    state = state.copyWith(sending: true, clearError: true);
    try {
      _connection!.send({'chat_contents': _pendingText!});
      _ackTimer = Timer(
        const Duration(seconds: 15),
        () => _lost(_epoch, _version),
      );
    } catch (e) {
      _lost(_epoch, _version);
    }
  }
}

final chatRoomVmProvider = NotifierProvider.autoDispose
    .family<ChatRoomVm, ChatRoomState, String>(ChatRoomVm.new);
