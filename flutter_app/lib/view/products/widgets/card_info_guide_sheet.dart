import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pokem_app/vm/products/product_guide_vm.dart';

const _reference = 'assets/guides/card_info_reference.png';

class CardInfoGuideSheet extends ConsumerWidget {
  const CardInfoGuideSheet({super.key});
  void _enlarge(BuildContext context) {
    showDialog<void>(
      context: context,
      builder: (context) => Dialog.fullscreen(
        child: Scaffold(
          appBar: AppBar(
            title: const Text('카드 예시'),
            leading: CloseButton(onPressed: () => Navigator.of(context).pop()),
          ),
          body: SafeArea(
            child: InteractiveViewer(
              minScale: 1,
              maxScale: 6,
              child: Center(
                child: Image.asset(
                  _reference,
                  fit: BoxFit.contain,
                  semanticLabel: '카드 하단에 J, M6a, 133/103, SAR가 표시된 예시',
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final preference = ref.watch(productGuideVmProvider);
    final vm = ref.read(productGuideVmProvider.notifier);
    final theme = Theme.of(context);
    return FractionallySizedBox(
      heightFactor: 0.9,
      child: PopScope(
        canPop: !preference.saving,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(
                        '카드 정보 입력 안내',
                        style: theme.textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 8),
                      const Text('카드 앞면 아래쪽을 왼쪽부터 확인해주세요.'),
                      const SizedBox(height: 16),

                      OutlinedButton.icon(
                        onPressed: () => _enlarge(context),
                        icon: const Icon(Icons.zoom_in),
                        label: const Text('카드 예시 확대해서 보기'),
                      ),
                      const SizedBox(height: 8),
                      GestureDetector(
                        onTap: () => _enlarge(context),
                        child: Image.asset(
                          _reference,
                          height: 190,
                          fit: BoxFit.contain,
                          semanticLabel: '입력 위치를 표시한 카드 예시. 눌러서 확대',
                          errorBuilder: (_, error, stack) =>
                              const SizedBox.shrink(),
                        ),
                      ),
                      const SizedBox(height: 16),
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: theme.colorScheme.primaryContainer,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Wrap(
                          alignment: WrapAlignment.center,
                          crossAxisAlignment: WrapCrossAlignment.center,
                          spacing: 8,
                          runSpacing: 8,
                          children: [
                            for (final field in cardInfoGuideFields)
                              Text(
                                field.example,
                                style: theme.textTheme.titleMedium?.copyWith(
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 12),
                      for (final (index, field) in cardInfoGuideFields.indexed)
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 8),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              CircleAvatar(
                                radius: 13,
                                child: Text(
                                  '${index + 1}',
                                  style: const TextStyle(fontSize: 12),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      '${field.label} · ${field.example}',
                                      style: theme.textTheme.titleSmall
                                          ?.copyWith(
                                            fontWeight: FontWeight.w700,
                                          ),
                                    ),
                                    const SizedBox(height: 3),
                                    Text(field.description),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      const SizedBox(height: 8),
                      const Text(
                        '133/103처럼 앞 숫자가 더 커도 카드에 적힌 그대로 입력해주세요. 001처럼 앞에 0이 있으면 함께 입력합니다.',
                      ),
                      const SizedBox(height: 12),
                    ],
                  ),
                ),
              ),
              CheckboxListTile(
                contentPadding: EdgeInsets.zero,
                controlAffinity: ListTileControlAffinity.leading,
                title: const Text('다시 보지 않기'),
                value: preference.selected,
                onChanged: preference.saving || !preference.ready
                    ? null
                    : (value) => vm.select(value ?? false),
              ),
              if (preference.error != null)
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Semantics(
                    liveRegion: true,
                    child: Text(
                      preference.error!,
                      style: TextStyle(color: theme.colorScheme.error),
                    ),
                  ),
                ),
              FilledButton(
                onPressed: preference.saving || !preference.ready
                    ? null
                    : () async {
                        final saved = await vm.confirm();
                        if (context.mounted && saved) {
                          Navigator.of(context).pop();
                        }
                      },
                child: Text(preference.saving ? '저장 중' : '확인'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
