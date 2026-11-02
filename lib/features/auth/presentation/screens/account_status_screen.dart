import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import '../../../../core/presentation/widgets/adaptive_layout.dart';
import '../../domain/user_entity.dart';
import '../providers/auth_providers.dart';

class AccountStatusScreen extends ConsumerStatefulWidget {
  const AccountStatusScreen({super.key});
  @override
  ConsumerState<AccountStatusScreen> createState() =>
      _AccountStatusScreenState();
}

class _AccountStatusScreenState extends ConsumerState<AccountStatusScreen> {
  final _name = TextEditingController();
  final _phone = TextEditingController();
  bool _saving = false;
  String? _error;
  @override
  void dispose() {
    _name.dispose();
    _phone.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final auth = ref.watch(authStateProvider);
    final profile = ref.watch(currentUserProfileProvider);
    final loading = auth.isLoading || profile.isLoading;
    return Scaffold(
      appBar: AppBar(title: const Text('Your account')),
      body: AdaptiveContent(
        maxWidth: 560,
        child: loading
            ? const Center(
                child: CircularProgressIndicator(
                  semanticsLabel: 'Loading your account',
                ),
              )
            : Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (auth.hasError || profile.hasError)
                    FeedbackPanel(
                      title: 'Your account could not load',
                      message: 'Check your connection, then retry.',
                      onRetry: () {
                        ref.invalidate(authStateProvider);
                        ref.invalidate(currentUserProfileProvider);
                      },
                    )
                  else if (auth.value != null && profile.value == null) ...[
                    Text(
                      'Finish setting up your account',
                      style: Theme.of(context).textTheme.headlineSmall,
                    ),
                    const SizedBox(height: 12),
                    const Text(
                      'Your sign-in is ready. Add your name and phone number to create your customer profile.',
                    ),
                    const SizedBox(height: 24),
                    TextField(
                      controller: _name,
                      maxLength: 100,
                      decoration: const InputDecoration(labelText: 'Full name'),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: _phone,
                      maxLength: 30,
                      keyboardType: TextInputType.phone,
                      decoration: const InputDecoration(
                        labelText: 'Contact phone',
                      ),
                    ),
                    if (_error != null)
                      Text(
                        _error!,
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.error,
                        ),
                      ),
                    const SizedBox(height: 16),
                    FilledButton(
                      onPressed: _saving
                          ? null
                          : () async {
                              if (_name.text.trim().isEmpty ||
                                  _phone.text.trim().isEmpty) {
                                setState(
                                  () => _error =
                                      'Enter your name and phone number.',
                                );
                                return;
                              }
                              setState(() {
                                _saving = true;
                                _error = null;
                              });
                              final identity = auth.value!;
                              final result = await ref
                                  .read(authRemoteServiceProvider)
                                  .createUserProfile(
                                    UserEntity(
                                      uid: identity.uid,
                                      role: UserRole.customer,
                                      fullName: _name.text.trim(),
                                      email: identity.email ?? '',
                                      phone: _phone.text.trim(),
                                      createdAt: DateTime.now(),
                                    ),
                                  );
                              if (!mounted) return;
                              setState(() {
                                _saving = false;
                                result.fold(
                                  (failure) => _error = failure.message,
                                  (_) => _error = null,
                                );
                              });
                            },
                      child: Text(_saving ? 'Saving…' : 'Complete setup'),
                    ),
                  ],
                  const SizedBox(height: 20),
                  TextButton(
                    onPressed: _saving
                        ? null
                        : () => ref.read(authRemoteServiceProvider).signOut(),
                    child: const Text('Sign out'),
                  ),
                ],
              ),
      ),
    );
  }
}
