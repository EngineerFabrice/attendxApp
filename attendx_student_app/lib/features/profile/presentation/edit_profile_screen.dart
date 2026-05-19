import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:dio/dio.dart';
import '../../../core/network/api_client.dart';
import '../../../core/network/api_endpoints.dart';
import '../../../core/storage/secure_storage.dart';
import '../../auth/domain/user_model.dart';
import '../../auth/presentation/providers/auth_provider.dart';
import '../../../shared/widgets/primary_button.dart';

class EditProfileScreen extends ConsumerStatefulWidget {
  const EditProfileScreen({super.key});

  @override
  ConsumerState<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends ConsumerState<EditProfileScreen> {
  final _formKey     = GlobalKey<FormState>();
  final _nameCtrl    = TextEditingController();
  final _phoneCtrl   = TextEditingController();
  bool  _saving      = false;

  @override
  void initState() {
    super.initState();
    final user = ref.read(authProvider).user;
    if (user != null) {
      _nameCtrl.text  = user.fullName;
      _phoneCtrl.text = user.phone ?? '';
    }
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _phoneCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);
    try {
      final dio = ApiClient().dio;
      final res = await dio.put(ApiEndpoints.updateProfile, data: {
        'fullName': _nameCtrl.text.trim(),
        'phone':    _phoneCtrl.text.trim().isEmpty ? null : _phoneCtrl.text.trim(),
      });
      final updated = UserModel.fromJson(
          res.data['data'] as Map<String, dynamic>);
      // Persist updated user to secure storage
      await SecureStorage().saveUser(updated.toJsonString());
      // Refresh auth provider state
      await ref.read(authProvider.notifier).checkAuthStatus();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Profile updated successfully'),
          backgroundColor: Colors.green,
        ),
      );
      Navigator.pop(context);
    } on DioException catch (e) {
      final msg = e.response?.data?['error'] as String? ?? 'Update failed';
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(msg), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final user    = ref.watch(authProvider).user;
    final primary = Theme.of(context).primaryColor;

    return Scaffold(
      appBar: AppBar(title: const Text('Edit Profile')),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Avatar
                Center(
                  child: Stack(
                    alignment: Alignment.bottomRight,
                    children: [
                      CircleAvatar(
                        radius: 48,
                        backgroundColor: primary,
                        child: Text(
                          (user?.fullName[0] ?? 'S').toUpperCase(),
                          style: const TextStyle(
                              fontSize: 36, color: Colors.white),
                        ),
                      ),
                      Container(
                        decoration: BoxDecoration(
                          color: primary,
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.white, width: 2),
                        ),
                        padding: const EdgeInsets.all(4),
                        child: const Icon(Icons.edit,
                            size: 14, color: Colors.white),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 32),

                // Full name
                TextFormField(
                  controller: _nameCtrl,
                  textCapitalization: TextCapitalization.words,
                  textInputAction: TextInputAction.next,
                  decoration: const InputDecoration(
                    labelText: 'Full name',
                    prefixIcon: Icon(Icons.person_outline),
                    border: OutlineInputBorder(),
                  ),
                  validator: (v) {
                    if (v == null || v.trim().isEmpty) {
                      return 'Name is required';
                    }
                    if (v.trim().length < 2) return 'At least 2 characters';
                    return null;
                  },
                ),
                const SizedBox(height: 16),

                // Phone number
                TextFormField(
                  controller: _phoneCtrl,
                  keyboardType: TextInputType.phone,
                  textInputAction: TextInputAction.done,
                  decoration: const InputDecoration(
                    labelText: 'Phone number (optional)',
                    prefixIcon: Icon(Icons.phone_outlined),
                    border: OutlineInputBorder(),
                    hintText: '+250 7XX XXX XXX',
                  ),
                ),
                const SizedBox(height: 8),

                // Read-only info
                if (user != null) ...[
                  const SizedBox(height: 8),
                  _ReadonlyField(
                      label: 'Email', value: user.email,
                      icon: Icons.email_outlined),
                  const SizedBox(height: 8),
                  if (user.regNumber != null)
                    _ReadonlyField(
                        label: 'Registration No.',
                        value: user.regNumber!,
                        icon: Icons.badge_outlined),
                ],

                const SizedBox(height: 32),

                PrimaryButton(
                  onPressed: _save,
                  text: 'Save Changes',
                  isLoading: _saving,
                  width: double.infinity,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _ReadonlyField extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  const _ReadonlyField(
      {required this.label, required this.value, required this.icon});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade300),
      ),
      child: Row(
        children: [
          Icon(icon, size: 20, color: Colors.grey.shade500),
          const SizedBox(width: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label,
                  style: TextStyle(
                      fontSize: 11, color: Colors.grey.shade500)),
              Text(value,
                  style: const TextStyle(fontSize: 14)),
            ],
          ),
          const Spacer(),
          Icon(Icons.lock_outline, size: 14, color: Colors.grey.shade400),
        ],
      ),
    );
  }
}
