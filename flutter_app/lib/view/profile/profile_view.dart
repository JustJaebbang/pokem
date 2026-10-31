import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pokem_app/model/profile/user_profile.dart';
import 'package:pokem_app/vm/profile/profile_vm.dart';

class ProfileView extends ConsumerStatefulWidget {
  const ProfileView({super.key});
  @override
  ConsumerState<ProfileView> createState() => _ProfileViewState();
}

class _ProfileViewState extends ConsumerState<ProfileView> {
  final _form = GlobalKey<FormState>();
  final _phone = TextEditingController();
  final _email = TextEditingController();
  final _address = TextEditingController();
  UserProfile? _displayed;
  @override
  void dispose() {
    _phone.dispose();
    _email.dispose();
    _address.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(profileVmProvider);
    final vm = ref.read(profileVmProvider.notifier);
    final profile = state.profile;
    if (profile != null && !identical(profile, _displayed)) {
      _displayed = profile;
      _phone.text = profile.phone;
      _email.text = profile.email;
      _address.text = profile.address;
    }
    return PopScope(
      canPop: !state.saving,
      child: Scaffold(
        appBar: AppBar(title: const Text('회원정보 수정')),
        body: state.loading
            ? const Center(child: CircularProgressIndicator())
            : profile == null
            ? Center(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(state.error ?? '회원정보를 불러오지 못했습니다.'),
                      TextButton(
                        onPressed: vm.load,
                        child: const Text('다시 시도'),
                      ),
                    ],
                  ),
                ),
              )
            : Form(
                key: _form,
                child: ListView(
                  padding: const EdgeInsets.all(24),
                  children: [
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      title: Text(
                        profile.nickname,
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                      subtitle: Text('${profile.name} · ${profile.id}'),
                    ),
                    const SizedBox(height: 20),
                    TextFormField(
                      key: const Key('profilePhone'),
                      controller: _phone,
                      enabled: !state.saving,
                      decoration: const InputDecoration(labelText: '전화번호'),
                      keyboardType: TextInputType.phone,
                      textInputAction: TextInputAction.next,
                      validator: vm.validatePhone,
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      key: const Key('profileEmail'),
                      controller: _email,
                      enabled: !state.saving,
                      decoration: const InputDecoration(labelText: '이메일'),
                      keyboardType: TextInputType.emailAddress,
                      textInputAction: TextInputAction.next,
                      validator: vm.validateEmail,
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      key: const Key('profileAddress'),
                      controller: _address,
                      enabled: !state.saving,
                      decoration: const InputDecoration(labelText: '주소'),
                      minLines: 2,
                      maxLines: 4,
                      keyboardType: TextInputType.streetAddress,
                      validator: vm.validateAddress,
                    ),
                    if (state.error != null)
                      Padding(
                        padding: const EdgeInsets.only(top: 16),
                        child: Text(
                          state.error!,
                          style: TextStyle(
                            color: Theme.of(context).colorScheme.error,
                          ),
                        ),
                      ),
                    const SizedBox(height: 24),
                    FilledButton(
                      onPressed: state.saving
                          ? null
                          : () async {
                              if (!_form.currentState!.validate()) return;
                              final saved = await vm.save(
                                ProfileInput(
                                  phone: _phone.text,
                                  email: _email.text,
                                  address: _address.text,
                                ),
                              );
                              if (!context.mounted || !saved) return;
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(content: Text('회원정보를 저장했습니다.')),
                              );
                              Navigator.of(context).pop();
                            },
                      child: Text(state.saving ? '저장 중' : '저장'),
                    ),
                  ],
                ),
              ),
      ),
    );
  }
}
