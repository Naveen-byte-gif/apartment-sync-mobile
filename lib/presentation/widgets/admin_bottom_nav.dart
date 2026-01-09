import 'package:flutter/material.dart';
import 'premium_bottom_nav.dart';

/// Admin-specific bottom navigation bar widget
///
/// This widget encapsulates the admin navigation items and configuration,
/// making it reusable and easier to maintain.
class AdminBottomNav extends StatelessWidget {
  /// Current selected index
  final int currentIndex;

  /// Callback function when a tab is tapped
  final Function(int) onTap;

  const AdminBottomNav({
    super.key,
    required this.currentIndex,
    required this.onTap,
  });

  /// Admin navigation items configuration
  static const List<NavItem> items = [
    NavItem(icon: Icons.dashboard, label: ''),
    NavItem(icon: Icons.people, label: ''),
    NavItem(icon: Icons.article_outlined, label: ''),
    NavItem(icon: Icons.chat_bubble_outline, label: ''),
    NavItem(icon: Icons.person, label: ''),
  ];

  @override
  Widget build(BuildContext context) {
    return PremiumBottomNav(
      currentIndex: currentIndex,
      onTap: (index) {
        print('🖱️ [FLUTTER] Admin tab changed to index: $index');
        onTap(index);
      },
      items: items,
    );
  }
}
