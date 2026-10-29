import 'dart:convert';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:image/image.dart' as img;
import 'package:image_picker/image_picker.dart';

import 'api_config.dart';

const _maxPhotoBytes = 46 * 1024;

class PostItemPage extends StatefulWidget {
  const PostItemPage({super.key, required this.token, this.onCreated});

  final String token;
  final Future<void> Function()? onCreated;

  @override
  State<PostItemPage> createState() => _PostItemPageState();
}

class _PostItemPageState extends State<PostItemPage> {
  final _formKey = GlobalKey<FormState>();
  final _regulation = TextEditingController();
  final _packType = TextEditingController();
  final _element = TextEditingController();
  final _setNumber = TextEditingController();
  final _rarity = TextEditingController();
  final _title = TextEditingController();
  final _contents = TextEditingController();
  final _price = TextEditingController();
  final _picker = ImagePicker();
  Uint8List? _photoBytes;
  String? _photoMimeType;
  String? _photoName;
  bool _pickingPhoto = false;
  bool _loading = false;
  String? _createdProductCode;

  @override
  void dispose() {
    for (final controller in [
      _regulation,
      _packType,
      _element,
      _setNumber,
      _rarity,
      _title,
      _contents,
      _price,
    ]) {
      controller.dispose();
    }
    super.dispose();
  }

  Future<void> _pickPhoto(
      ImageSource source, FormFieldState<Uint8List?> field) async {
    if (_pickingPhoto || _loading) return;
    setState(() => _pickingPhoto = true);
    try {
      final file = await _picker.pickImage(
        source: source,
        maxWidth: 720,
        maxHeight: 720,
        imageQuality: 45,
        requestFullMetadata: false,
      );
      if (file == null) return;
      final pickedBytes = await file.readAsBytes();
      late Uint8List bytes;
      late String mimeType;
      try {
        mimeType = _getSupportedImageType(file.mimeType, pickedBytes);
        bytes = pickedBytes;
      } on FormatException {
        bytes = _compressPhoto(pickedBytes);
        mimeType = 'image/jpeg';
      }
      if (bytes.lengthInBytes > _maxPhotoBytes) {
        bytes = _compressPhoto(bytes);
        mimeType = 'image/jpeg';
      }
      if (!mounted) return;
      setState(() {
        _photoBytes = bytes;
        _photoMimeType = mimeType;
        _photoName = file.name;
      });
      field.didChange(bytes);
    } on FormatException catch (error) {
      _showMessage(error.message.toString());
    } catch (error, stackTrace) {
      debugPrint('Product photo selection failed: $error\n$stackTrace');
      _showMessage('사진을 선택할 수 없습니다: $error');
    } finally {
      if (mounted) setState(() => _pickingPhoto = false);
    }
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _loading = true);
    try {
      final imageData = _photoBytes == null
          ? ''
          : 'data:${_photoMimeType ?? 'image/jpeg'};base64,${base64Encode(_photoBytes!)}';
      final response = await http
          .post(
            Uri.parse('$apiBaseUrl/sell_product'),
            headers: {
              'Content-Type': 'application/json',
              'Authorization': 'Bearer ${widget.token}',
            },
            body: jsonEncode({
              'regulation': _regulation.text.trim(),
              'card_pack_type': _packType.text.trim(),
              'element_of_set': _element.text.trim(),
              'set': _setNumber.text.trim(),
              'rarity': _rarity.text.trim(),
              'sell_product_title': _title.text.trim(),
              'sell_product_image': imageData,
              'sell_product_contents': _contents.text.trim(),
              'sell_product_sell_price': int.parse(_price.text.trim()),
            }),
          )
          .timeout(const Duration(seconds: 30));
      final data = jsonDecode(utf8.decode(response.bodyBytes));
      if (response.statusCode == 201 || response.statusCode == 200) {
        if (!mounted) return;
        setState(() {
          _createdProductCode = data is Map<String, dynamic>
              ? data['sell_product_code']?.toString()
              : null;
        });
        await widget.onCreated?.call();
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('상품을 등록했습니다.')),
        );
        for (final controller in [
          _regulation,
          _packType,
          _element,
          _setNumber,
          _rarity,
          _title,
          _contents,
          _price,
        ]) {
          controller.clear();
        }
        setState(() {
          _photoBytes = null;
          _photoMimeType = null;
          _photoName = null;
        });
      } else {
        final message =
            data is Map<String, dynamic> ? data['detail']?.toString() : null;
        _showMessage(message ?? '상품 등록에 실패했습니다.');
      }
    } catch (_) {
      _showMessage('상품 등록에 실패했습니다. 서버 연결과 사진 크기를 확인해 주세요.');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _showMessage(String message) => ScaffoldMessenger.of(context)
      .showSnackBar(SnackBar(content: Text(message)));

  String _getSupportedImageType(String? reportedType, Uint8List bytes) {
    const supported = {'image/jpeg', 'image/png', 'image/webp'};
    if (reportedType != null && supported.contains(reportedType)) {
      return reportedType;
    }
    if (bytes.length >= 3 &&
        bytes[0] == 0xFF &&
        bytes[1] == 0xD8 &&
        bytes[2] == 0xFF) {
      return 'image/jpeg';
    }
    if (bytes.length >= 8 &&
        bytes[0] == 0x89 &&
        bytes[1] == 0x50 &&
        bytes[2] == 0x4E &&
        bytes[3] == 0x47) {
      return 'image/png';
    }
    if (bytes.length >= 12 &&
        String.fromCharCodes(bytes.sublist(0, 4)) == 'RIFF' &&
        String.fromCharCodes(bytes.sublist(8, 12)) == 'WEBP') {
      return 'image/webp';
    }
    throw const FormatException(
        '이 사진 형식은 지원하지 않습니다. JPEG, PNG 또는 WebP 사진을 선택해 주세요.');
  }

  Uint8List _compressPhoto(Uint8List input) {
    try {
      final decoded = img.decodeImage(input);
      if (decoded == null) {
        throw const FormatException('사진 형식을 읽을 수 없습니다.');
      }
      final longestSide = math.max(decoded.width, decoded.height);
      for (final limit in [720, 600, 480, 360]) {
        final scale = math.min(1.0, limit / longestSide);
        final targetWidth = math.max(1, (decoded.width * scale).round());
        final resized = img.copyResize(decoded, width: targetWidth);
        for (final quality in [55, 40, 25, 15]) {
          final encoded =
              Uint8List.fromList(img.encodeJpg(resized, quality: quality));
          if (encoded.lengthInBytes <= _maxPhotoBytes) return encoded;
        }
      }
    } catch (error) {
      debugPrint('Product photo compression failed: $error');
    }
    throw const FormatException(
        '사진을 압축하지 못했습니다. JPEG, PNG 또는 WebP 사진을 선택해 주세요.');
  }

  String? _required(String? value) =>
      value == null || value.trim().isEmpty ? '필수 입력 항목입니다.' : null;

  Widget _field(
    TextEditingController controller,
    String label, {
    String? Function(String?)? validator,
    TextInputType? keyboardType,
    int maxLines = 1,
  }) =>
      Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: TextFormField(
          controller: controller,
          decoration: InputDecoration(
            labelText: label,
            border: const OutlineInputBorder(),
          ),
          validator: validator ?? _required,
          keyboardType: keyboardType,
          maxLines: maxLines,
        ),
      );

  Widget _photoPicker() => FormField<Uint8List?>(
        validator: (_) => _photoBytes == null ? '상품 사진을 선택해 주세요.' : null,
        builder: (field) => Padding(
          padding: const EdgeInsets.only(bottom: 18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (_photoBytes == null)
                Container(
                  height: 210,
                  width: double.infinity,
                  decoration: BoxDecoration(
                    color: const Color(0xFFF0F1F6),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: const Icon(Icons.add_photo_alternate_outlined,
                      size: 48, color: Color(0xFF9AA0AD)),
                )
              else
                ClipRRect(
                  borderRadius: BorderRadius.circular(16),
                  child: Image.memory(
                    _photoBytes!,
                    height: 240,
                    width: double.infinity,
                    fit: BoxFit.cover,
                  ),
                ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                children: [
                  OutlinedButton.icon(
                    onPressed: _pickingPhoto || _loading
                        ? null
                        : () => _pickPhoto(ImageSource.gallery, field),
                    icon: const Icon(Icons.photo_library_outlined),
                    label: Text(_photoBytes == null ? '앨범에서 선택' : '사진 바꾸기'),
                  ),
                  OutlinedButton.icon(
                    onPressed: _pickingPhoto || _loading
                        ? null
                        : () => _pickPhoto(ImageSource.camera, field),
                    icon: const Icon(Icons.camera_alt_outlined),
                    label: const Text('카메라'),
                  ),
                ],
              ),
              if (_photoName != null)
                Text(
                  '$_photoName · ${(_photoBytes!.length / 1024).toStringAsFixed(0)} KB',
                  style:
                      const TextStyle(color: Color(0xFF747887), fontSize: 12),
                ),
              if (field.errorText != null)
                Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Text(field.errorText!,
                      style: TextStyle(
                          color: Theme.of(context).colorScheme.error,
                          fontSize: 12)),
                ),
            ],
          ),
        ),
      );

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: const Text('상품 등록')),
        body: Form(
          key: _formKey,
          child: ListView(
            padding: const EdgeInsets.all(20),
            children: [
              if (_createdProductCode != null && _createdProductCode!.isNotEmpty)
                Container(
                  margin: const EdgeInsets.only(bottom: 16),
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: const Color(0xFFECEAFF),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('최근 등록 상품',
                          style: TextStyle(fontWeight: FontWeight.w700)),
                      const SizedBox(height: 5),
                      SelectableText('상품 코드  $_createdProductCode'),
                      const SizedBox(height: 4),
                      const Text(
                        '판매 등록 기록은 위 상품 코드를 그대로 연결해 서버에서 생성합니다. 등록 코드의 앞부분도 이 상품 코드와 같습니다.',
                        style: TextStyle(fontSize: 12, color: Color(0xFF747887)),
                      ),
                    ],
                  ),
                ),
              const Text('판매 정보',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
              const SizedBox(height: 14),
              _field(_title, '상품명'),
              _photoPicker(),
              _field(_contents, '상품 설명', validator: (_) => null, maxLines: 4),
              _field(
                _price,
                '판매 가격',
                keyboardType: TextInputType.number,
                validator: (value) {
                  final price = int.tryParse(value?.trim() ?? '');
                  return price == null || price < 0
                      ? '0 이상의 원 단위 금액을 입력해 주세요.'
                      : null;
                },
              ),
              const Text(
                '사진은 40KB 이하 JPEG로 압축해 기존 상품 이미지 필드에 저장합니다.',
                style: TextStyle(fontSize: 12, color: Color(0xFF747887)),
              ),
              const SizedBox(height: 20),
              const Text('카드 정보',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
              const SizedBox(height: 14),
              _field(_regulation, '레귤레이션 코드 (예: J)'),
              _field(_packType, '카드 팩 종류 (예: m6a)'),
              _field(_element, '카드 번호 (예: 001)'),
              _field(_setNumber, '세트 번호 (예: 103)'),
              _field(_rarity, '레어도 (예: C)'),
              const Text(
                '상품 코드와 등록 번호는 서버에서 생성됩니다.',
                style: TextStyle(fontSize: 12, color: Color(0xFF747887)),
              ),
              const SizedBox(height: 20),
              SizedBox(
                height: 52,
                child: FilledButton(
                  onPressed: _loading || _pickingPhoto ? null : _submit,
                  child: _loading
                      ? const SizedBox(
                          width: 22,
                          height: 22,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Text('상품 등록하기'),
                ),
              ),
            ],
          ),
        ),
      );
}
