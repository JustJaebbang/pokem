import 'package:flutter/material.dart';

class PokemWordmark extends StatelessWidget {
  const PokemWordmark({super.key, this.size = 25, this.color});
  final double size;
  final Color? color;
  @override
  Widget build(BuildContext context) => Text(
    'POKEM',
    style: TextStyle(
      fontSize: size,
      fontWeight: FontWeight.w900,
      letterSpacing: 1.5,
      height: 1.1,
      color: color ?? Theme.of(context).colorScheme.primary,
    ),
  );
}
