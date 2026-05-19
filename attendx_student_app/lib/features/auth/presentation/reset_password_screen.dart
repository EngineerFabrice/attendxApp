import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'providers/auth_provider.dart';
import '../domain/auth_state.dart';
import '../../../shared/widgets/primary_button.dart';

class ResetPasswordScreen extends ConsumerStatefulWidget {
  const ResetPasswordScreen({super.key});

  @override
  ConsumerState<ResetPasswordScreen> createState() =>
      _ResetPasswordScreenState();
}

class _ResetPasswordScreenState extends ConsumerState<ResetPasswordScreen> {
  final _tokenController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmController = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  bool _isLoading = false;
  bool _showPassword = false;
  bool _showConfirm = false;
  bool _initialized = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_initialized) return;
    _initialized = true;
    final args =
        ModalRoute.of(context)?.settings.arguments as Map<String, dynamic>?;
    final devToken = args?['devToken'] as String?;
    if (devToken != null) {
      _tokenController.text = devToken;
    }
  }

  @override
  void dispose() {
    _tokenController.dispose();
    _passwordController.dispose();
    _confirmController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isLoading = true);

    await ref.read(authProvider.notifier).resetPassword(
          _tokenController.text.trim(),
          _passwordController.text,
        );

    setState(() => _isLoading = false);
    if (!mounted) return;

    final state = ref.read(authProvider);

    if (state is AuthPasswordResetSuccess) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Password updated! Please sign in.'),
          backgroundColor: Colors.green,
        ),
      );
      Navigator.pushNamedAndRemoveUntil(
          context, '/login', (route) => false);
    } else if (state is AuthError) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(state.message), backgroundColor: Colors.red),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final primaryColor = Theme.of(context).primaryColor;

    return Scaffold(
      appBar: AppBar(
        leading: const BackButton(),
        title: const Text('Set New Password'),
        elevation: 0,
        backgroundColor: Colors.transparent,
        foregroundColor: Colors.black87,
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Form(
            key: _formKey,
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 16),

                  Center(
                    child: Container(
                      width: 80,
                      height: 80,
                      decoration: BoxDecoration(
                        color: Colors.green.withValues(alpha: 0.1),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.lock_open_outlined,
                          size: 40, color: Colors.green),
                    ),
                  ),

                  const SizedBox(height: 32),

                  const Text(
                    'Enter your reset code',
                    style: TextStyle(
                        fontSize: 22, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Check your email for the reset code, then choose a new password.',
                    style: TextStyle(
                        fontSize: 14, color: Colors.grey.shade600),
                  ),

                  const SizedBox(height: 32),

                  // Reset token field
                  TextFormField(
                    controller: _tokenController,
                    keyboardType: TextInputType.text,
                    textInputAction: TextInputAction.next,
                    decoration: InputDecoration(
                      labelText: 'Reset code',
                      prefixIcon: const Icon(Icons.vpn_key_outlined),
                      border: const OutlineInputBorder(),
                      helperText: _tokenController.text.isNotEmpty
                          ? 'Pre-filled from email link'
                          : null,
                    ),
                    validator: (v) {
                      if (v == null || v.trim().isEmpty) {
                        return 'Please enter the reset code';
                      }
                      return null;
                    },
                  ),

                  const SizedBox(height: 16),

                  // New password
                  TextFormField(
                    controller: _passwordController,
                    obscureText: !_showPassword,
                    textInputAction: TextInputAction.next,
                    decoration: InputDecoration(
                      labelText: 'New password',
                      prefixIcon: const Icon(Icons.lock_outline),
                      border: const OutlineInputBorder(),
                      suffixIcon: IconButton(
                        icon: Icon(_showPassword
                            ? Icons.visibility_off
                            : Icons.visibility),
                        onPressed: () =>
                            setState(() => _showPassword = !_showPassword),
                      ),
                    ),
                    validator: (v) {
                      if (v == null || v.isEmpty) {
                        return 'Please enter a new password';
                      }
                      if (v.length < 8) {
                        return 'Password must be at least 8 characters';
                      }
                      if (!RegExp(r'[A-Z]').hasMatch(v)) {
                        return 'Include at least one uppercase letter';
                      }
                      if (!RegExp(r'[0-9]').hasMatch(v)) {
                        return 'Include at least one number';
                      }
                      return null;
                    },
                  ),

                  const SizedBox(height: 16),

                  // Confirm password
                  TextFormField(
                    controller: _confirmController,
                    obscureText: !_showConfirm,
                    textInputAction: TextInputAction.done,
                    onFieldSubmitted: (_) => _submit(),
                    decoration: InputDecoration(
                      labelText: 'Confirm password',
                      prefixIcon: const Icon(Icons.lock_outline),
                      border: const OutlineInputBorder(),
                      suffixIcon: IconButton(
                        icon: Icon(_showConfirm
                            ? Icons.visibility_off
                            : Icons.visibility),
                        onPressed: () =>
                            setState(() => _showConfirm = !_showConfirm),
                      ),
                    ),
                    validator: (v) {
                      if (v != _passwordController.text) {
                        return 'Passwords do not match';
                      }
                      return null;
                    },
                  ),

                  const SizedBox(height: 8),

                  // Password strength hint
                  _PasswordHint(password: _passwordController.text),

                  const SizedBox(height: 24),

                  PrimaryButton(
                    onPressed: _submit,
                    text: 'Update Password',
                    isLoading: _isLoading,
                    width: double.infinity,
                  ),

                  const SizedBox(height: 16),

                  Center(
                    child: TextButton(
                      onPressed: () => Navigator.pushNamedAndRemoveUntil(
                          context, '/login', (route) => false),
                      child: Text('Back to Sign In',
                          style: TextStyle(color: primaryColor)),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _PasswordHint extends StatelessWidget {
  final String password;
  const _PasswordHint({required this.password});

  @override
  Widget build(BuildContext context) {
    if (password.isEmpty) return const SizedBox.shrink();
    final checks = [
      _Check('At least 8 characters', password.length >= 8),
      _Check('One uppercase letter', RegExp(r'[A-Z]').hasMatch(password)),
      _Check('One number', RegExp(r'[0-9]').hasMatch(password)),
    ];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: checks
          .map((c) => Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Row(
                  children: [
                    Icon(
                      c.passed ? Icons.check_circle : Icons.radio_button_unchecked,
                      size: 16,
                      color: c.passed ? Colors.green : Colors.grey.shade400,
                    ),
                    const SizedBox(width: 6),
                    Text(c.label,
                        style: TextStyle(
                            fontSize: 12,
                            color: c.passed
                                ? Colors.green
                                : Colors.grey.shade500)),
                  ],
                ),
              ))
          .toList(),
    );
  }
}

class _Check {
  final String label;
  final bool passed;
  const _Check(this.label, this.passed);
}
