import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pokem_app/vm/products/products_vm.dart';

class ProductFilters extends ConsumerWidget {
  const ProductFilters({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selected = ref.watch(productsVmProvider);
    final options = ref.watch(productClassificationsProvider);
    return options.when(
      loading: () => const LinearProgressIndicator(),
      error: (_, _) => TextButton.icon(
        onPressed: () => ref.invalidate(productClassificationsProvider),
        icon: const Icon(Icons.refresh),
        label: const Text('상품 분류 다시 불러오기'),
      ),
      data: (rows) {
        final categories =
            rows
                .map((r) => r.category)
                .whereType<String>()
                .where((v) => v.trim().isNotEmpty)
                .toSet()
                .toList()
              ..sort();
        final brands =
            rows
                .where(
                  (r) =>
                      selected.category == null ||
                      r.category == selected.category,
                )
                .map((r) => r.brand)
                .whereType<String>()
                .where((v) => v.trim().isNotEmpty)
                .toSet()
                .toList()
              ..sort();
        Widget choices(
          String label,
          List<String> values,
          String? current,
          ValueChanged<String?> onSelect,
        ) => Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label, style: Theme.of(context).textTheme.labelLarge),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  for (final value in <String?>[null, ...values])
                    Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: ChoiceChip(
                        label: Text(value ?? '전체'),
                        selected: current == value,
                        onSelected: (_) => onSelect(value),
                      ),
                    ),
                ],
              ),
            ),
          ],
        );
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (categories.isNotEmpty)
              choices('카테고리', categories, selected.category, (value) {
                ref
                    .read(productsVmProvider.notifier)
                    .selectFilters(category: value);
              }),
            if (brands.isNotEmpty)
              choices('브랜드', brands, selected.brand, (value) {
                ref
                    .read(productsVmProvider.notifier)
                    .selectFilters(category: selected.category, brand: value);
              }),
          ],
        );
      },
    );
  }
}
