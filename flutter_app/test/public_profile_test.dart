import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/testing.dart';
import 'package:pokem_app/core/providers/data_providers.dart';
import 'package:pokem_app/model/chat/chat_models.dart';
import 'package:pokem_app/model/profile/public_profile.dart';
import 'package:pokem_app/repository/profile/public_profile_repository.dart';
import 'package:pokem_app/service/profile/public_profile_api_service.dart';
import 'package:pokem_app/view/profile/widgets/profile_avatar.dart';
import 'package:pokem_app/view/profile/widgets/public_profile_header.dart';
import 'package:pokem_app/view/chat/chat_rooms_view.dart';
import 'package:pokem_app/view/chat/chat_room_view.dart';
import 'package:pokem_app/vm/auth/login_vm.dart';

import 'auth_test.dart' as auth;
import 'chat_test.dart' as chat;

final image = '/media/products/${'a' * 32}.jpg';
Map<String, dynamic> profile({String id = 'seller', bool retired = false}) => {
  'user_id': id,
  'user_nickname': retired ? '탈퇴한 사용자' : '상대 닉네임',
  'user_profile_image': retired ? null : image,
  'is_withdrawn': retired,
};
void main() {
  test(
    'public profile request has no private account endpoint or token',
    () async {
      final repo = PublicProfileRepository(
        PublicProfileApiService(
          MockClient((r) async {
            expect(r.url.path, '/profiles/seller');
            expect(r.headers.containsKey('Authorization'), isFalse);
            return auth.response(profile());
          }),
          baseUrl: 'http://test.local',
        ),
      );
      expect((await repo.get('seller')).imageUrl, image);
    },
  );
  test('mismatched public profile id is rejected', () async {
    final repo = PublicProfileRepository(
      PublicProfileApiService(
        MockClient((_) async => auth.response(profile(id: 'other'))),
        baseUrl: 'http://test.local',
      ),
    );
    await expectLater(
      repo.get('seller'),
      throwsA(isA<PublicProfileException>()),
    );
  });
  test('chat metadata supports older API and retired image masking', () {
    final old = ChatRoom.fromJson({
      'chat_room_id': 'R',
      'chat_room_name': '상품',
      'chat_room_status': '대화중',
      'sell_product_sell_product_code': 'P1',
      'inquirer_user_id': 'buyer',
      'seller_user_id': 'seller',
    });
    expect(old.displayOther('buyer'), 'seller');
    expect(old.displayOtherImage, isNull);
    final retired = ChatRoom(
      id: 'R',
      name: '상품',
      status: '대화중',
      productCode: 'P1',
      buyerId: 'buyer',
      sellerId: 'seller',
      otherNickname: '이전 이름',
      otherImage: image,
      otherWithdrawn: true,
    );
    expect(retired.displayOther('buyer'), '탈퇴한 사용자');
    expect(retired.displayOtherImage, isNull);
  });
  testWidgets(
    'public header displays nickname and photo without private fields',
    (tester) async {
      final repo = PublicProfileRepository(
        PublicProfileApiService(
          MockClient((_) async => auth.response(profile())),
          baseUrl: 'http://test.local',
        ),
      );
      await tester.pumpWidget(
        ProviderScope(
          overrides: [publicProfileRepositoryProvider.overrideWithValue(repo)],
          child: const MaterialApp(
            home: Scaffold(body: PublicProfileHeader(userId: 'seller')),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('상대 닉네임'), findsOneWidget);
      expect(
        tester.widget<ProfileAvatar>(find.byType(ProfileAvatar)).url,
        image,
      );
    },
  );
  testWidgets('failed public header keeps fallback and retry can recover', (
    tester,
  ) async {
    var fail = true;
    final repo = PublicProfileRepository(
      PublicProfileApiService(
        MockClient(
          (_) async => fail
              ? auth.response({}, 503)
              : auth.response(profile(retired: true)),
        ),
        baseUrl: 'http://test.local',
      ),
    );
    await tester.pumpWidget(
      ProviderScope(
        overrides: [publicProfileRepositoryProvider.overrideWithValue(repo)],
        child: const MaterialApp(
          home: Scaffold(body: PublicProfileHeader(userId: 'seller')),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('판매자 seller'), findsOneWidget);
    fail = false;
    await tester.tap(find.byTooltip('판매자 프로필 다시 불러오기'));
    await tester.pumpAndSettle();
    expect(find.text('탈퇴한 사용자'), findsOneWidget);
    expect(
      tester.widget<ProfileAvatar>(find.byType(ProfileAvatar)).url,
      isNull,
    );
  });
  testWidgets('chat list and room header show opponent nickname and image', (
    tester,
  ) async {
    final repository = chat.FakeChatRepository()
      ..currentRoom = ChatRoom(
        id: 'CR_1',
        name: '피카츄 카드',
        status: '대화중',
        productCode: 'P1',
        buyerId: 'tester',
        sellerId: 'seller',
        otherNickname: '상대 닉네임',
        otherImage: image,
      );
    final c = ProviderContainer(
      overrides: [
        authRepositoryProvider.overrideWithValue(
          auth.repository(
            auth.MemoryStorage(),
            (_) => auth.response(auth.loginResponse()),
          ),
        ),
        chatRepositoryProvider.overrideWithValue(repository),
      ],
    );
    addTearDown(c.dispose);
    await tester.runAsync(() async {
      c.read(loginVmProvider);
      await Future<void>.delayed(Duration.zero);
      await c
          .read(loginVmProvider.notifier)
          .login('tester', 'pw', remember: false);
    });
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: c,
        child: const MaterialApp(home: Scaffold(body: ChatRoomsView())),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('상대 닉네임'), findsOneWidget);
    expect(tester.widget<ProfileAvatar>(find.byType(ProfileAvatar)).url, image);
    await tester.tap(find.text('상대 닉네임'));
    await tester.pumpAndSettle();
    expect(find.byType(ChatRoomView), findsOneWidget);
    expect(find.text('상대 닉네임'), findsOneWidget);
    expect(find.text('피카츄 카드'), findsOneWidget);
    await tester.pageBack();
    await tester.pumpAndSettle();
  });
}
