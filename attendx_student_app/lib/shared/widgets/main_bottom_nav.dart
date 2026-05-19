import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../features/messages/presentation/messages_provider.dart';

class MainBottomNav extends ConsumerWidget {
  final int currentIndex;

  const MainBottomNav({super.key, required this.currentIndex});

  static const _routes = [
    '/dashboard',
    '/history',
    '/analytics',
    '/messages',
    '/profile',
  ];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final unread = ref.watch(
      messagesProvider.select((s) => s.unreadCount),
    );

    return BottomNavigationBar(
      currentIndex: currentIndex,
      type: BottomNavigationBarType.fixed,
      selectedItemColor: Theme.of(context).primaryColor,
      unselectedItemColor: Colors.grey,
      onTap: (index) {
        if (index == currentIndex) return;
        Navigator.pushReplacementNamed(context, _routes[index]);
      },
      items: [
        const BottomNavigationBarItem(
          icon: Icon(Icons.dashboard_outlined),
          activeIcon: Icon(Icons.dashboard),
          label: 'Home',
        ),
        const BottomNavigationBarItem(
          icon: Icon(Icons.history_outlined),
          activeIcon: Icon(Icons.history),
          label: 'History',
        ),
        const BottomNavigationBarItem(
          icon: Icon(Icons.bar_chart_outlined),
          activeIcon: Icon(Icons.bar_chart),
          label: 'Analytics',
        ),
        BottomNavigationBarItem(
          icon: _BadgeIcon(
            icon: Icons.notifications_outlined,
            count: unread,
          ),
          activeIcon: _BadgeIcon(
            icon: Icons.notifications,
            count: unread,
            isActive: true,
          ),
          label: 'Notifications',
        ),
        const BottomNavigationBarItem(
          icon: Icon(Icons.person_outline),
          activeIcon: Icon(Icons.person),
          label: 'Profile',
        ),
      ],
    );
  }
}

class _BadgeIcon extends StatelessWidget {
  final IconData icon;
  final int count;
  final bool isActive;

  const _BadgeIcon({
    required this.icon,
    required this.count,
    this.isActive = false,
  });

  @override
  Widget build(BuildContext context) {
    final color = isActive
        ? Theme.of(context).primaryColor
        : Colors.grey;

    if (count == 0) return Icon(icon, color: color);

    return Badge(
      label: Text(
        count > 99 ? '99+' : '$count',
        style: const TextStyle(fontSize: 10),
      ),
      child: Icon(icon, color: color),
    );
  }
}
