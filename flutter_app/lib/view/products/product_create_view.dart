import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:pokem_app/model/products/product_form_input.dart';
import 'package:pokem_app/vm/products/product_create_vm.dart';

class ProductCreateView extends ConsumerStatefulWidget {
  const ProductCreateView({super.key});
  @override
  ConsumerState<ProductCreateView> createState() => _ProductCreateViewState();
}

class _ProductCreateViewState extends ConsumerState<ProductCreateView> {
  final _form = GlobalKey<FormState>();
  final _controllers = {
    for (final field in [
      'title',
      'description',
      'price',
      'regulation',
      'packType',
      'element',
      'setNumber',
      'rarity',
    ])
      field: TextEditingController(),
  };
  @override
  void initState() {
    super.initState();
    Future.microtask(() {
      if (mounted) {
        ref.read(productCreateVmProvider.notifier).pickPhoto(recover: true);
      }
    });
  }

  @override
  void dispose() {
    for (final controller in _controllers.values) {
      controller.dispose();
    }
    super.dispose();
  }

  String _text(String name) => _controllers[name]!.text;
  Future<void> _submit() async {
    if (!_form.currentState!.validate()) return;
    FocusScope.of(context).unfocus();
    final product = await ref
        .read(productCreateVmProvider.notifier)
        .submit(
          ProductFormInput(
            title: _text('title'),
            description: _text('description'),
            price: _text('price'),
            regulation: _text('regulation'),
            packType: _text('packType'),
            element: _text('element'),
            setNumber: _text('setNumber'),
            rarity: _text('rarity'),
          ),
        );
    if (!mounted || product == null) return;
    Navigator.of(context).pop(product);
  }

  Widget _field(
    String name,
    String label, {
    int lines = 1,
    int? limit,
    bool money = false,
  }) {
    final state = ref.watch(productCreateVmProvider);
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: TextFormField(
        key: Key('product-$name'),
        controller: _controllers[name],
        enabled: !state.busy,
        maxLines: lines,
        maxLength: limit,
        keyboardType: money ? TextInputType.number : null,
        inputFormatters: money
            ? [FilteringTextInputFormatter.digitsOnly]
            : null,
        decoration: InputDecoration(
          labelText: label,
          counterText: '',
          suffixText: money ? '원' : null,
        ),
        validator: (value) => ref
            .read(productCreateVmProvider.notifier)
            .validateField(name, value),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(productCreateVmProvider);
    final vm = ref.read(productCreateVmProvider.notifier);
    final theme = Theme.of(context);
    return PopScope(
      canPop: !state.busy,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('상품 등록'),
          automaticallyImplyLeading: !state.busy,
        ),
        body: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: Center(
              child: SizedBox(
                width: 520,
                child: Form(
                  key: _form,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      InkWell(
                        key: const Key('selectProductPhoto'),
                        onTap: state.busy || state.picking
                            ? null
                            : () => vm.pickPhoto(),
                        borderRadius: BorderRadius.circular(18),
                        child: Container(
                          clipBehavior: Clip.antiAlias,
                          decoration: BoxDecoration(
                            color: const Color(0xFFE5ECD8),
                            borderRadius: BorderRadius.circular(18),
                          ),
                          child: AspectRatio(
                            aspectRatio: 1.5,
                            child: state.photo == null
                                ? Column(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Icon(
                                        Icons.add_photo_alternate_outlined,
                                        size: 46,
                                        color: theme.colorScheme.primary,
                                      ),
                                      const SizedBox(height: 12),
                                      Text(
                                        state.picking ? '불러오는 중' : '사진 업로드',
                                        style: theme.textTheme.titleMedium,
                                      ),
                                    ],
                                  )
                                : Image.memory(
                                    state.photo!.bytes,
                                    fit: BoxFit.contain,
                                    errorBuilder: (_, error, stackTrace) =>
                                        const Center(
                                          child: Text(
                                            '사진을 미리 볼 수 없습니다. 다시 선택해주세요.',
                                          ),
                                        ),
                                  ),
                          ),
                        ),
                      ),
                      if (state.photo != null)
                        TextButton(
                          onPressed: state.busy || state.picking
                              ? null
                              : vm.removePhoto,
                          child: const Text('사진 삭제'),
                        ),
                      if (state.photoError != null)
                        Padding(
                          padding: const EdgeInsets.only(top: 12),
                          child: Semantics(
                            liveRegion: true,
                            child: Text(
                              state.photoError!,
                              key: const Key('photoError'),
                              style: TextStyle(color: theme.colorScheme.error),
                            ),
                          ),
                        ),
                      const SizedBox(height: 10),
                      const Text(
                        'JPEG·PNG·WebP / 최대 5MB',
                        style: TextStyle(
                          fontSize: 12,
                          color: Color(0xFF67716A),
                        ),
                      ),
                      const SizedBox(height: 24),
                      _field('title', '상품명', limit: 100),
                      Text('카드 정보', style: theme.textTheme.titleMedium),
                      const SizedBox(height: 8),
                      const Text(
                        '카드에 표시된 정보를 입력해주세요.',
                        style: TextStyle(
                          fontSize: 12,
                          color: Color(0xFF67716A),
                        ),
                      ),
                      const SizedBox(height: 16),
                      _field('regulation', '레귤레이션'),
                      _field('packType', '카드 팩 구분'),
                      _field('element', '세트 구성'),
                      _field('setNumber', '세트 번호'),
                      _field('rarity', '레어도'),
                      _field('description', '상품 설명', lines: 4, limit: 500),
                      const Text(
                        '일반 판매 · 검수 등급 미지정',
                        style: TextStyle(color: Color(0xFF67716A)),
                      ),
                      const SizedBox(height: 16),
                      _field('price', '가격', limit: 10, money: true),
                      if (state.error != null)
                        Container(
                          key: const Key('productCreateError'),
                          margin: const EdgeInsets.only(bottom: 16),
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: theme.colorScheme.errorContainer,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Semantics(
                            liveRegion: true,
                            child: Text(
                              state.error!,
                              style: TextStyle(
                                color: theme.colorScheme.onErrorContainer,
                              ),
                            ),
                          ),
                        ),
                      FilledButton(
                        key: const Key('submitProduct'),
                        onPressed: state.busy || state.picking ? null : _submit,
                        style: FilledButton.styleFrom(
                          minimumSize: const Size.fromHeight(56),
                        ),
                        child: state.busy
                            ? Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const SizedBox(
                                    width: 18,
                                    height: 18,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Text(state.phase),
                                ],
                              )
                            : const Text('등록하기'),
                      ),
                      const SizedBox(height: 20),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
