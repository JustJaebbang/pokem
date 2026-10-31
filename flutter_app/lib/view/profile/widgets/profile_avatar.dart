import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:pokem_app/core/media/product_image_url.dart';

class ProfileAvatar extends StatelessWidget {
  const ProfileAvatar({super.key, this.url, this.bytes, this.size = 72});
  final String? url;
  final Uint8List? bytes;
  final double size;
  @override
  Widget build(BuildContext context) {
    final placeholder = ColoredBox(
      color: Theme.of(context).colorScheme.surfaceContainerHighest,
      child: Icon(
        Icons.person_outline,
        size: size * 0.6,
        color: Theme.of(context).colorScheme.primary,
      ),
    );
    final resolved = url == null ? null : resolveProductImage(url!);
    return SizedBox(
      width: size,
      height: size,
      child: ClipOval(
        child: bytes != null
            ? Image.memory(
                bytes!,
                fit: BoxFit.cover,
                errorBuilder: (_, _, _) => placeholder,
              )
            : resolved == null
            ? placeholder
            : Image.network(
                resolved,
                fit: BoxFit.cover,
                errorBuilder: (_, _, _) => placeholder,
                loadingBuilder: (_, child, progress) =>
                    progress == null ? child : placeholder,
              ),
      ),
    );
  }
}
