import 'package:flutter/material.dart';

class ChatPage extends StatelessWidget {
  const ChatPage({super.key});

  @override
  Widget build(BuildContext context) => const Center(
        child: Padding(
          padding: EdgeInsets.all(28),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Icon(Icons.chat_bubble_outline_rounded,
                size: 48, color: Color(0xFF6658E8)),
            SizedBox(height: 14),
            Text('채팅',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800)),
            SizedBox(height: 8),
            Text('채팅 기능을 준비하고 있어요.',
                style: TextStyle(color: Color(0xFF858B9A))),
          ]),
        ),
      );
}
