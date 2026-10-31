import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pokem_app/model/products/product.dart';
import 'package:pokem_app/model/products/product_edit.dart';
import 'package:pokem_app/view/products/widgets/product_image.dart';
import 'package:pokem_app/vm/products/product_edit_vm.dart';

class ProductEditView extends ConsumerStatefulWidget {
  const ProductEditView({super.key, required this.code});
  final String code;
  @override
  ConsumerState<ProductEditView> createState() => _ProductEditViewState();
}

class _ProductEditViewState extends ConsumerState<ProductEditView> {
  final _form = GlobalKey<FormState>();
  final _title = TextEditingController();
  final _description = TextEditingController();
  final _price = TextEditingController();
  Product? _displayed;
  @override
  void dispose() {
    _title.dispose();
    _description.dispose();
    _price.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(productEditVmProvider(widget.code));
    final vm = ref.read(productEditVmProvider(widget.code).notifier);
    final product = state.product;
    if (product != null && !identical(product, _displayed)) {
      _displayed = product;
      _title.text = product.title;
      _description.text = product.description;
      _price.text = '${product.price}';
    }
    final enabled = state.canEdit && !state.saving && !state.picking;
    return PopScope(
      canPop: !state.saving && !state.picking,
      child: Scaffold(
        appBar: AppBar(title: const Text('상품 수정')),
        body: state.loading
            ? const Center(child: CircularProgressIndicator())
            : Form(
                key: _form,
                child: ListView(
                  padding: const EdgeInsets.all(24),
                  children: [
                    if (product != null) ...[
                      InkWell(
                        key: const Key('editProductPhoto'),
                        onTap: enabled ? vm.pickPhoto : null,
                        child: SizedBox(
                          height: 180,
                          child: state.photo == null
                              ? ProductImage(
                                  url: product.image,
                                  fit: BoxFit.contain,
                                )
                              : Image.memory(
                                  state.photo!.bytes,
                                  fit: BoxFit.contain,
                                  errorBuilder: (_, _, _) =>
                                      const Icon(Icons.broken_image_outlined),
                                ),
                        ),
                      ),
                      if (state.canEdit)
                        Wrap(
                          spacing: 12,
                          children: [
                            OutlinedButton(
                              onPressed: enabled ? vm.pickPhoto : null,
                              child: Text(
                                state.picking ? '사진 불러오는 중' : '사진 변경',
                              ),
                            ),
                            if (state.photo != null)
                              TextButton(
                                onPressed: enabled ? vm.useOriginalPhoto : null,
                                child: const Text('기존 사진 사용'),
                              ),
                          ],
                        ),
                      if (state.photoError != null)
                        Padding(
                          padding: const EdgeInsets.only(top: 8),
                          child: Text(
                            state.photoError!,
                            key: const Key('editPhotoError'),
                            style: TextStyle(
                              color: Theme.of(context).colorScheme.error,
                            ),
                          ),
                        ),
                      const SizedBox(height: 20),
                      if (!state.canEdit)
                        const Padding(
                          padding: EdgeInsets.only(bottom: 16),
                          child: Text(
                            '판매중인 본인 일반판매 상품만 수정할 수 있습니다. 대리판매 상품은 담당자가 관리합니다.',
                          ),
                        ),
                      TextFormField(
                        key: const Key('editTitle'),
                        controller: _title,
                        enabled: enabled,
                        maxLength: 100,
                        validator: vm.validateTitle,
                        decoration: const InputDecoration(labelText: '상품명'),
                      ),
                      const SizedBox(height: 16),
                      TextFormField(
                        key: const Key('editDescription'),
                        controller: _description,
                        enabled: enabled,
                        maxLength: 500,
                        maxLines: 5,
                        validator: vm.validateDescription,
                        decoration: const InputDecoration(labelText: '상품 설명'),
                      ),
                      const SizedBox(height: 16),
                      TextFormField(
                        key: const Key('editPrice'),
                        controller: _price,
                        enabled: enabled,
                        keyboardType: TextInputType.number,
                        inputFormatters: [
                          FilteringTextInputFormatter.digitsOnly,
                        ],
                        validator: vm.validatePrice,
                        decoration: const InputDecoration(
                          labelText: '가격',
                          suffixText: '원',
                        ),
                      ),
                      const SizedBox(height: 24),
                      FilledButton(
                        onPressed: enabled
                            ? () async {
                                if (!_form.currentState!.validate()) return;
                                final saved = await vm.save(
                                  ProductEditInput(
                                    title: _title.text,
                                    description: _description.text,
                                    price: _price.text,
                                  ),
                                );
                                if (!context.mounted || !saved) return;
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(content: Text('상품을 수정했습니다.')),
                                );
                                Navigator.of(context).pop();
                              }
                            : null,
                        child: Text(state.saving ? '저장 중' : '저장'),
                      ),
                    ],
                    if (state.error != null)
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        child: Text(
                          state.error!,
                          style: TextStyle(
                            color: Theme.of(context).colorScheme.error,
                          ),
                        ),
                      ),
                    TextButton(
                      onPressed: state.saving || state.picking ? null : vm.load,
                      child: const Text('새로고침'),
                    ),
                  ],
                ),
              ),
      ),
    );
  }
}
