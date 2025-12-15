import '../../../core/imports/app_imports.dart';
import 'resident_notices_screen.dart';

class NoticesScreen extends StatelessWidget {
  const NoticesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    // Use dynamic notices screen
    return const ResidentNoticesScreen();
    return Scaffold(
      appBar: AppBar(
        title: const Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Notices'),
            Text(
              '2 unread',
              style: TextStyle(fontSize: 12, fontWeight: FontWeight.normal),
            ),
          ],
        ),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              children: [
                // Search Bar
                TextField(
                  decoration: InputDecoration(
                    hintText: 'Search notices...',
                    prefixIcon: const Icon(Icons.search),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                    filled: true,
                    fillColor: Colors.white,
                  ),
                ),
                const SizedBox(height: 16),
                // Filter Chips
                SizedBox(
                  height: 40,
                  child: ListView(
                    scrollDirection: Axis.horizontal,
                    children: [
                      _FilterChip(label: 'All', isSelected: true),
                      const SizedBox(width: 8),
                      _FilterChip(label: 'General', isSelected: false),
                      const SizedBox(width: 8),
                      _FilterChip(label: 'Maintenance', isSelected: false),
                      const SizedBox(width: 8),
                      _FilterChip(label: 'Security', isSelected: false),
                      const SizedBox(width: 8),
                      _FilterChip(label: 'Events', isSelected: false),
                    ],
                  ),
                ),
              ],
            ),
          ),
          // Notices List
          Expanded(
            child: ListView(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              children: [
                _NoticeItem(
                  icon: Icons.notifications,
                  title: 'Water Supply Interruption',
                  description:
                      'Water supply will be interrupted on Dec 5th from 10 AM to 2 PM for tank cleaning...',
                  date: 'Dec 3, 2025',
                  isUnread: true,
                  tag: 'Important',
                ),
                const SizedBox(height: 12),
                _NoticeItem(
                  icon: Icons.campaign,
                  title: 'Annual Society Meeting',
                  description:
                      'All residents are requested to attend the annual general meeting scheduled on Dec 10th...',
                  date: 'Dec 2, 2025',
                  isUnread: true,
                ),
                const SizedBox(height: 12),
                _NoticeItem(
                  icon: Icons.security,
                  title: 'Security Update',
                  description:
                      'New visitor management system will be implemented from next week. All visitors must...',
                  date: 'Dec 1, 2025',
                  isUnread: false,
                  tag: 'Important',
                ),
                const SizedBox(height: 12),
                _NoticeItem(
                  icon: Icons.receipt,
                  title: 'Maintenance Due Reminder',
                  description:
                      'Reminder: November maintenance dues are pending. Please pay by Dec 15th to avoid late fees...',
                  date: 'Nov 30, 2025',
                  isUnread: false,
                ),
                const SizedBox(height: 12),
                _NoticeItem(
                  icon: Icons.celebration,
                  title: 'Diwali Celebration',
                  description:
                      'Join us for the community Diwali celebration on Nov 12th at 7 PM in the clubhouse...',
                  date: 'Nov 28, 2025',
                  isUnread: false,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _FilterChip extends StatelessWidget {
  final String label;
  final bool isSelected;

  const _FilterChip({
    required this.label,
    required this.isSelected,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: isSelected ? AppColors.primary : AppColors.border,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: isSelected ? Colors.white : Colors.grey.shade700,
          fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
        ),
      ),
    );
  }
}

class _NoticeItem extends StatelessWidget {
  final IconData icon;
  final String title;
  final String description;
  final String date;
  final bool isUnread;
  final String? tag;

  const _NoticeItem({
    required this.icon,
    required this.title,
    required this.description,
    required this.date,
    required this.isUnread,
    this.tag,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: AppColors.primary, size: 24),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        title,
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: isUnread ? FontWeight.bold : FontWeight.normal,
                        ),
                      ),
                    ),
                    if (isUnread)
                      Container(
                        width: 8,
                        height: 8,
                        decoration: const BoxDecoration(
                          color: AppColors.primary,
                          shape: BoxShape.circle,
                        ),
                      ),
                  ],
                ),
                if (tag != null) ...[
                  const SizedBox(height: 4),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.pink.shade100,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      tag!,
                      style: TextStyle(
                        color: Colors.pink.shade700,
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
                const SizedBox(height: 4),
                Text(
                  description,
                  style: const TextStyle(
                    fontSize: 12,
                    color: Colors.grey,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 4),
                Text(
                  date,
                  style: const TextStyle(
                    fontSize: 12,
                    color: Colors.grey,
                  ),
                ),
              ],
            ),
          ),
          const Icon(Icons.arrow_forward_ios, size: 16, color: Colors.grey),
        ],
      ),
    );
  }
}

