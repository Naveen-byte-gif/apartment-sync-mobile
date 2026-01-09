import 'package:flutter/material.dart';
import '../../../core/imports/app_imports.dart';

class LogBookScreen extends StatefulWidget {
  const LogBookScreen({super.key});

  @override
  State<LogBookScreen> createState() => _LogBookScreenState();
}

class _LogBookScreenState extends State<LogBookScreen> {
  String _selectedFilter = 'All Logs';

  final List<Map<String, dynamic>> _logs = [
    {
      'title': 'Gate Patrol Completed',
      'person': 'Ramesh Kumar',
      'description': 'Main gate and parking area checked. All clear.',
      'date': '02 Jan, 08:43 PM',
      'priority': 'low',
      'status': 'completed',
      'type': 'Security',
      'icon': Icons.security,
      'iconColor': Colors.green,
    },
    {
      'title': 'Lift Maintenance',
      'person': 'Suresh Patel',
      'description': 'Block A lift servicing completed by Johnson Lifts.',
      'date': '02 Jan, 07:13 PM',
      'priority': 'medium',
      'status': 'completed',
      'type': 'Maintenance',
      'icon': Icons.build,
      'iconColor': Colors.green,
    },
    {
      'title': 'Suspicious Activity',
      'person': 'Vikram Singh',
      'description': 'Unknown person spotted near basement. Verified as delivery agent.',
      'date': '02 Jan, 05:13 PM',
      'priority': 'high',
      'status': 'completed',
      'type': 'Security',
      'icon': Icons.security,
      'iconColor': Colors.green,
    },
    {
      'title': 'Water Tank Cleaning',
      'person': 'Maintenance Team',
      'description': 'Scheduled cleaning in progress for Block B.',
      'date': '02 Jan, 04:30 PM',
      'priority': 'medium',
      'status': 'in_progress',
      'type': 'Maintenance',
      'icon': Icons.build,
      'iconColor': Colors.orange,
    },
  ];

  @override
  Widget build(BuildContext context) {
    final filteredLogs = _selectedFilter == 'All Logs'
        ? _logs
        : _logs.where((log) => log['type'] == _selectedFilter).toList();

    return Scaffold(
      backgroundColor: const Color(0xFF0F1419),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.menu, color: Colors.white),
          onPressed: () {
            Scaffold.of(context).openDrawer();
          },
        ),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Log Book',
              style: TextStyle(
                color: Colors.white,
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
            Text(
              'Activity records',
              style: TextStyle(
                color: Colors.white70,
                fontSize: 12,
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.search, color: Colors.white),
            onPressed: () {},
          ),
          Stack(
            children: [
              IconButton(
                icon: const Icon(Icons.notifications, color: Colors.white),
                onPressed: () {},
              ),
              Positioned(
                right: 8,
                top: 8,
                child: Container(
                  padding: const EdgeInsets.all(4),
                  decoration: const BoxDecoration(
                    color: Colors.red,
                    shape: BoxShape.circle,
                  ),
                  child: const Text(
                    '3',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
      body: Column(
        children: [
          // Filter Tabs
          SizedBox(
            height: 50,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              children: ['All Logs', 'Maintenance', 'Security', 'Visitor'].map((filter) {
                final isSelected = _selectedFilter == filter;
                return Padding(
                  padding: const EdgeInsets.only(right: 12),
                  child: GestureDetector(
                    onTap: () {
                      setState(() => _selectedFilter = filter);
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      decoration: BoxDecoration(
                        color: isSelected ? Colors.green : const Color(0xFF1A2332),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Row(
                        children: [
                          if (filter == 'All Logs')
                            const Icon(Icons.assignment, color: Colors.white, size: 18),
                          if (filter == 'Maintenance')
                            const Icon(Icons.build, color: Colors.white, size: 18),
                          if (filter == 'Security')
                            const Icon(Icons.security, color: Colors.white, size: 18),
                          if (filter == 'Visitor')
                            const Icon(Icons.person, color: Colors.white, size: 18),
                          if (filter != 'All Logs') const SizedBox(width: 8),
                          Text(
                            filter,
                            style: TextStyle(
                              color: Colors.white,
                              fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
          ),

          // Logs List
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: filteredLogs.length,
              itemBuilder: (context, index) {
                return _LogCard(log: filteredLogs[index]);
              },
            ),
          ),
        ],
      ),
      // Removed bottom navigation bar as per requirements
    );
  }

}

class _LogCard extends StatelessWidget {
  final Map<String, dynamic> log;

  const _LogCard({required this.log});

  Color _getPriorityColor(String priority) {
    switch (priority.toLowerCase()) {
      case 'high':
        return Colors.red;
      case 'medium':
        return Colors.orange;
      case 'low':
        return Colors.green;
      default:
        return Colors.grey;
    }
  }

  Color _getStatusColor(String status) {
    switch (status.toLowerCase()) {
      case 'completed':
        return Colors.green;
      case 'in_progress':
        return Colors.orange;
      case 'pending':
        return Colors.blue;
      default:
        return Colors.grey;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF1A2332),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: log['iconColor'].withOpacity(0.2),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  log['icon'],
                  color: log['iconColor'],
                  size: 24,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      log['title'],
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      log['person'],
                      style: TextStyle(
                        color: Colors.white70,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: _getPriorityColor(log['priority']).withOpacity(0.2),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  log['priority'],
                  style: TextStyle(
                    color: _getPriorityColor(log['priority']),
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            log['description'],
            style: TextStyle(
              color: Colors.white70,
              fontSize: 14,
            ),
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                log['date'],
                style: TextStyle(
                  color: Colors.white60,
                  fontSize: 12,
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: _getStatusColor(log['status']).withOpacity(0.2),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  log['status'],
                  style: TextStyle(
                    color: _getStatusColor(log['status']),
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}


