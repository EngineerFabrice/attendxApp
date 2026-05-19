import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../auth/presentation/providers/auth_provider.dart';
import '../../../../shared/widgets/main_bottom_nav.dart';
import '../../../../core/services/biometric_service.dart';

class ProfileScreen extends ConsumerStatefulWidget {
  const ProfileScreen({super.key});

  @override
  ConsumerState<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends ConsumerState<ProfileScreen> {
  bool _biometricsEnabled = false;
  bool _biometricsAvailable = false;
  bool _togglingBiometrics = false;

  @override
  void initState() {
    super.initState();
    _loadBiometricState();
  }

  Future<void> _loadBiometricState() async {
    final available = await BiometricService.isAvailable();
    final enabled = await BiometricService.isEnabled();
    if (mounted) {
      setState(() {
        _biometricsAvailable = available;
        _biometricsEnabled = enabled;
      });
    }
  }

  Future<void> _toggleBiometrics(bool value) async {
    if (_togglingBiometrics) return;
    setState(() => _togglingBiometrics = true);

    // Always authenticate first before changing setting
    final passed = await BiometricService.authenticate(
      reason: value
          ? 'Confirm identity to enable biometric lock'
          : 'Confirm identity to disable biometric lock',
    );

    if (!mounted) return;
    if (!passed) {
      setState(() => _togglingBiometrics = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Authentication required to change this setting.'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    await BiometricService.setEnabled(value);
    setState(() {
      _biometricsEnabled = value;
      _togglingBiometrics = false;
    });

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(value
              ? 'Biometric lock enabled.'
              : 'Biometric lock disabled.'),
          backgroundColor: Colors.green,
        ),
      );
    }
  }

  String _formatDate(DateTime date) =>
      '${date.day}/${date.month}/${date.year}';

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authProvider);
    final user = authState.user;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Profile'),
      ),
      bottomNavigationBar: const MainBottomNav(currentIndex: 4),
      body: user == null
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.person_off_outlined,
                      size: 64, color: Colors.grey),
                  const SizedBox(height: 16),
                  const Text('Not signed in'),
                  const SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: () => Navigator.pushReplacementNamed(
                        context, '/login'),
                    child: const Text('Sign In'),
                  ),
                ],
              ),
            )
          : ListView(
              children: [
                const SizedBox(height: 32),
                Center(
                  child: CircleAvatar(
                    radius: 50,
                    backgroundColor: Theme.of(context).primaryColor,
                    child: Text(
                      user.fullName[0].toUpperCase(),
                      style: const TextStyle(
                          fontSize: 40, color: Colors.white),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Center(
                  child: Text(
                    user.fullName,
                    style: const TextStyle(
                        fontSize: 24, fontWeight: FontWeight.bold),
                  ),
                ),
                Center(
                  child: Text(
                    user.regNumber ?? 'No Reg Number',
                    style: TextStyle(color: Colors.grey.shade600),
                  ),
                ),
                const SizedBox(height: 8),
                Center(
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.blue.shade100,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      user.role.toUpperCase(),
                      style: const TextStyle(
                          fontSize: 12, fontWeight: FontWeight.bold),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: OutlinedButton.icon(
                    onPressed: () =>
                        Navigator.pushNamed(context, '/edit-profile'),
                    icon: const Icon(Icons.edit_outlined),
                    label: const Text('Edit Profile'),
                    style: OutlinedButton.styleFrom(
                      minimumSize: const Size.fromHeight(44),
                    ),
                  ),
                ),
                const SizedBox(height: 24),

                Card(
                  margin: const EdgeInsets.symmetric(
                      horizontal: 16, vertical: 8),
                  child: ListTile(
                    leading: const Icon(Icons.email_outlined),
                    title: const Text('Email'),
                    subtitle: Text(user.email),
                  ),
                ),

                if (user.phone != null)
                  Card(
                    margin: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 8),
                    child: ListTile(
                      leading: const Icon(Icons.phone_outlined),
                      title: const Text('Phone'),
                      subtitle: Text(user.phone!),
                    ),
                  ),

                Card(
                  margin: const EdgeInsets.symmetric(
                      horizontal: 16, vertical: 8),
                  child: ListTile(
                    leading: const Icon(Icons.calendar_today),
                    title: const Text('Member Since'),
                    subtitle: Text(_formatDate(user.createdAt)),
                  ),
                ),

                Card(
                  margin: const EdgeInsets.symmetric(
                      horizontal: 16, vertical: 8),
                  child: ListTile(
                    leading: const Icon(Icons.notifications_outlined),
                    title: const Text('Notification Preferences'),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () => Navigator.pushNamed(
                        context, '/notification-preferences'),
                  ),
                ),

                // ── Security Section ──────────────────────────────────────
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 20, 16, 4),
                  child: Text(
                    'Security',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: Colors.grey.shade500,
                      letterSpacing: 0.5,
                    ),
                  ),
                ),

                Card(
                  margin: const EdgeInsets.symmetric(
                      horizontal: 16, vertical: 4),
                  child: _biometricsAvailable
                      ? SwitchListTile(
                          secondary: Icon(
                            Icons.fingerprint,
                            color: _biometricsEnabled
                                ? Theme.of(context).primaryColor
                                : Colors.grey,
                          ),
                          title: const Text('Biometric Lock'),
                          subtitle: Text(
                            _biometricsEnabled
                                ? 'App locked on resume · Required before check-in'
                                : 'Tap to enable fingerprint / Face ID lock',
                            style: TextStyle(
                                fontSize: 12,
                                color: Colors.grey.shade600),
                          ),
                          value: _biometricsEnabled,
                          onChanged: _togglingBiometrics
                              ? null
                              : _toggleBiometrics,
                        )
                      : const ListTile(
                          leading: Icon(Icons.fingerprint,
                              color: Colors.grey),
                          title: Text('Biometric Lock'),
                          subtitle: Text(
                            'No biometrics enrolled on this device.',
                            style: TextStyle(fontSize: 12),
                          ),
                          trailing: Icon(Icons.block,
                              color: Colors.grey, size: 18),
                        ),
                ),

                Card(
                  margin: const EdgeInsets.symmetric(
                      horizontal: 16, vertical: 4),
                  child: ListTile(
                    leading:
                        const Icon(Icons.lock_reset, color: Colors.orange),
                    title: const Text('Change Password'),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () =>
                        Navigator.pushNamed(context, '/forgot-password'),
                  ),
                ),

                const SizedBox(height: 24),

                Padding(
                  padding: const EdgeInsets.all(16),
                  child: ElevatedButton(
                    onPressed: () async {
                      await ref.read(authProvider.notifier).logout();
                      if (context.mounted) {
                        Navigator.pushReplacementNamed(context, '/login');
                      }
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.red,
                      foregroundColor: Colors.white,
                    ),
                    child: const Text('Logout'),
                  ),
                ),
              ],
            ),
    );
  }
}
