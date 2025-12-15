import '../../../core/imports/app_imports.dart';
import '../../../data/models/complaint_data.dart';
import 'resident_complaints_screen.dart';

class ComplaintsScreen extends StatelessWidget {
  const ComplaintsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    // Use the new resident complaints screen with real data
    return const ResidentComplaintsScreen();
    return Scaffold(
      appBar: AppBar(
        title: const Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Complaints'),
            Text(
              'Track and manage issues',
              style: TextStyle(fontSize: 12, fontWeight: FontWeight.normal),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.filter_list),
            onPressed: () {},
          ),
        ],
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
                    hintText: 'Search complaints...',
                    prefixIcon: const Icon(Icons.search),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                    filled: true,
                    fillColor: Colors.white,
                  ),
                ),
                const SizedBox(height: 16),
                // Raise New Complaint Button
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: () {},
                    icon: const Icon(Icons.add),
                    label: const Text('Raise New Complaint'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                  ),
                ),
              ],
            ),
          ),
          // Complaints List
          Expanded(
            child: ListView(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              children: [
                const Text(
                  'Your Complaints (4)',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 16),
                _ComplaintListItem(
                  title: 'Water leakage in bathroom',
                  description: 'Heavy leakage from ceiling near bathroom',
                  date: 'Dec 1, 2025',
                  status: 'In Progress',
                  statusColor: Colors.orange,
                  categoryIcon: Icons.water_drop,
                  categoryColor: Colors.blue,
                ),
                const SizedBox(height: 12),
                _ComplaintListItem(
                  title: 'Power fluctuation in bedroom',
                  description: 'Frequent voltage drops causing appliance issues',
                  date: 'Nov 30, 2025',
                  status: 'Assigned',
                  statusColor: Colors.purple,
                  categoryIcon: Icons.flash_on,
                  categoryColor: Colors.yellow,
                ),
                const SizedBox(height: 12),
                _ComplaintListItem(
                  title: 'Broken door handle',
                  description: 'Main door handle broke off',
                  date: 'Nov 28, 2025',
                  status: 'Resolved',
                  statusColor: Colors.green,
                  categoryIcon: Icons.build,
                  categoryColor: Colors.purple,
                ),
                const SizedBox(height: 12),
                _ComplaintListItem(
                  title: 'Parking gate malfunction',
                  description: 'Gate not responding to remote',
                  date: 'Nov 25, 2025',
                  status: 'Open',
                  statusColor: Colors.blue,
                  categoryIcon: Icons.security,
                  categoryColor: Colors.red,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ComplaintListItem extends StatelessWidget {
  final String title;
  final String description;
  final String date;
  final String status;
  final Color statusColor;
  final IconData categoryIcon;
  final Color categoryColor;

  const _ComplaintListItem({
    required this.title,
    required this.description,
    required this.date,
    required this.status,
    required this.statusColor,
    required this.categoryIcon,
    required this.categoryColor,
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
        children: [
          Container(
            width: 50,
            height: 50,
            decoration: BoxDecoration(
              color: categoryColor.withOpacity(0.2),
              shape: BoxShape.circle,
            ),
            child: Icon(categoryIcon, color: categoryColor),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  description,
                  style: const TextStyle(
                    fontSize: 12,
                    color: Colors.grey,
                  ),
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
          Column(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: statusColor.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 8,
                      height: 8,
                      decoration: BoxDecoration(
                        color: statusColor,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      status,
                      style: TextStyle(
                        color: statusColor,
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 8),
              const Icon(Icons.arrow_forward_ios, size: 16, color: Colors.grey),
            ],
          ),
        ],
      ),
    );
  }
}

