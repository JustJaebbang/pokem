import 'dart:typed_data';

class ProductPhoto {
  const ProductPhoto({required this.bytes, required this.filename});
  final Uint8List bytes;
  final String filename;
}
