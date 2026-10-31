import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pokem_app/vm/review/review_vm.dart';
import 'package:pokem_app/view/review/review_card.dart';

class ReviewView extends ConsumerStatefulWidget {
  const ReviewView({super.key, required this.code});
  final String code;
  @override
  ConsumerState<ReviewView> createState() => _ReviewViewState();
}

class _ReviewViewState extends ConsumerState<ReviewView> {
  final _contents = TextEditingController();
  final _form = GlobalKey<FormState>();
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) ref.read(reviewVmProvider(widget.code).notifier).load();
    });
  }

  @override
  void dispose() {
    _contents.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(reviewVmProvider(widget.code));
    final vm = ref.read(reviewVmProvider(widget.code).notifier);
    final snapshot = state.snapshot;
    return PopScope(
      canPop: !state.saving,
      child: Scaffold(
        appBar: AppBar(
          title: Text(snapshot?.review != null ? '내 후기' : '후기 작성'),
        ),
        body: state.loading
            ? const Center(child: CircularProgressIndicator())
            : Form(
                key: _form,
                child: ListView(
                  padding: const EdgeInsets.all(24),
                  children: [
                    if (snapshot != null) ...[
                      Text(
                        snapshot.purchase.title ??
                            snapshot.purchase.productCode,
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                      const SizedBox(height: 20),
                      if (snapshot.review != null)
                        ReviewCard(review: snapshot.review!)
                      else if (!snapshot.canWrite)
                        const Text('구매확정 후 후기를 작성할 수 있습니다.')
                      else ...[
                        const Text('거래는 어떠셨나요?'),
                        const SizedBox(height: 12),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            for (var rating = 1; rating <= 5; rating++)
                              IconButton(
                                tooltip: '$rating점',
                                onPressed: state.locked
                                    ? null
                                    : () => vm.rate(rating),
                                icon: Icon(
                                  state.rating >= rating
                                      ? Icons.star
                                      : Icons.star_border,
                                  color: Colors.amber,
                                ),
                              ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        TextFormField(
                          controller: _contents,
                          enabled: !state.locked,
                          maxLength: 500,
                          maxLines: 6,
                          validator: vm.validateContents,
                          decoration: const InputDecoration(
                            labelText: '후기',
                            hintText: '거래 경험을 남겨주세요.',
                          ),
                        ),
                        const SizedBox(height: 20),
                        if (!state.uncertain)
                          FilledButton(
                            onPressed: state.saving
                                ? null
                                : () {
                                    if (_form.currentState!.validate()) {
                                      vm.save(_contents.text);
                                    }
                                  },
                            child: Text(state.saving ? '등록 중' : '후기 등록'),
                          ),
                      ],
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
                      onPressed: state.saving ? null : () => vm.load(),
                      child: Text(state.uncertain ? '작성한 후기 확인' : '새로고침'),
                    ),
                  ],
                ),
              ),
      ),
    );
  }
}
