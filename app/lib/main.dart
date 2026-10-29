import 'package:flutter/material.dart';

import 'login.dart';

void main() => runApp(const PokemApp());

class PokemApp extends StatelessWidget {
  const PokemApp({super.key});

  @override
  Widget build(BuildContext context) {
    const ink = Color(0xFF20283B);
    return MaterialApp(
      title: 'PoKeM',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        scaffoldBackgroundColor: const Color(0xFFF7F8FC),
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF6658E8)),
        fontFamily: 'Roboto',
        appBarTheme: const AppBarTheme(
            backgroundColor: Color(0xFFF7F8FC), foregroundColor: ink),
      ),
      home: const LoginPage(),
    );
  }
}
