import 'package:pokem_app/model/products/product_photo.dart';
import 'package:flutter/foundation.dart';
import 'package:image_picker/image_picker.dart';

import 'package:pokem_app/model/products/product.dart';

class ProductPhotoPicker {
  final _picker = ImagePicker();
  Future<ProductPhoto?> pick() async {
    final file = await _picker.pickImage(
      source: ImageSource.gallery,
      maxWidth: 2400,
      maxHeight: 2400,
      imageQuality: 85,
      requestFullMetadata: false,
    );
    return file == null ? null : _read(file);
  }

  Future<ProductPhoto?> recover() async {
    if (kIsWeb || defaultTargetPlatform != TargetPlatform.android) return null;
    final response = await _picker.retrieveLostData();
    if (response.exception != null) {
      throw const ProductException('선택한 사진을 복구하지 못했습니다. 다시 선택해주세요.');
    }
    final files = response.files;
    return files == null || files.isEmpty ? null : _read(files.first);
  }

  Future<ProductPhoto> _read(XFile file) async {
    if (await file.length() > 5 * 1024 * 1024) {
      throw const ProductException('사진은 5MB 이하여야 합니다.');
    }
    final bytes = await file.readAsBytes();
    if (bytes.isEmpty) throw const ProductException('사진 파일이 비어 있습니다.');
    return ProductPhoto(bytes: bytes, filename: file.name);
  }
}
