import '../../../core/imports/app_imports.dart';
import '../auth/role_selection_screen.dart';
import '../home/tabs/news_tab_screen.dart';
import '../profile/profile_screen.dart';
import 'visitor_checkin_screen.dart';
import '../../widgets/app_sidebar.dart';

class StaffDashboardScreen extends StatefulWidget {
  const StaffDashboardScreen({super.key});

  @override
  State<StaffDashboardScreen> createState() => _StaffDashboardScreenState();
}

class _StaffDashboardScreenState extends State<StaffDashboardScreen> {
  int _currentIndex = 0;
  Map<String, dynamic>? _dashboardData;
  List<Map<String, dynamic>> _assignedComplaints = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadDashboardData();
    _setupSocketListeners();
  }

  void _setupSocketListeners() {
    print('🔌 [FLUTTER] Setting up socket listeners for staff');
  }

  Future<void> _loadDashboardData() async {
    print('🖱️ [FLUTTER] Loading staff dashboard data...');
    setState(() => _isLoading = true);
    try {
      // Load dashboard stats
      final response = await ApiService.get('/users/dashboard');
      print('✅ [FLUTTER] Staff dashboard response received');
      print('📦 [FLUTTER] Response: ${response.toString()}');

      if (response['success'] == true) {
        setState(() {
          _dashboardData = response['data']?['dashboard'];
        });
      }

      // Load assigned complaints
      // TODO: Add endpoint for staff assigned complaints
    } catch (e) {
      print('❌ [FLUTTER] Error loading dashboard: $e');
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Widget _getBodyForIndex(int index) {
    switch (index) {
      case 0:
        return _isLoading
            ? const Center(child: CircularProgressIndicator())
            : _buildDashboard();
      case 1:
        return const NewsTabScreen();
      case 2:
        return const ProfileScreen();
      default:
        return _isLoading
            ? const Center(child: CircularProgressIndicator())
            : _buildDashboard();
    }
  }

  Widget _buildDashboard() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Stats Cards
          Row(
            children: [
              Expanded(
                child: _StatCard(
                  title: 'Active Tasks',
                  value: '${_dashboardData?['activeComplaints'] ?? 0}',
                  icon: Icons.assignment,
                  color: Colors.blue,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _StatCard(
                  title: 'Completed',
                  value: '${_dashboardData?['resolvedComplaints'] ?? 0}',
                  icon: Icons.check_circle,
                  color: Colors.green,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _StatCard(
                  title: 'Total Tasks',
                  value: '${_dashboardData?['totalComplaints'] ?? 0}',
                  icon: Icons.list,
                  color: Colors.orange,
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          // Quick Actions
          const Text(
            'Quick Actions',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: Card(
                  child: InkWell(
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const VisitorCheckInScreen(),
                        ),
                      ).then((_) => _loadDashboardData());
                    },
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        children: [
                          Icon(Icons.qr_code_scanner, size: 40, color: AppColors.primary),
                          const SizedBox(height: 8),
                          const Text(
                            'Visitor Check-In',
                            style: TextStyle(fontWeight: FontWeight.bold),
                            textAlign: TextAlign.center,
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          // Assigned Complaints
          const Text(
            'Assigned Complaints',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 12),
          if (_assignedComplaints.isEmpty)
            Card(
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: Column(
                  children: [
                    Icon(Icons.assignment_outlined, size: 64, color: Colors.grey),
                    const SizedBox(height: 16),
                    const Text(
                      'No assigned complaints',
                      style: TextStyle(fontSize: 16, color: Colors.grey),
                    ),
                  ],
                ),
              ),
            )
          else
            ..._assignedComplaints.map((complaint) {
              return Card(
                margin: const EdgeInsets.only(bottom: 12),
                child: ListTile(
                  leading: CircleAvatar(
                    backgroundColor: Colors.blue.shade100,
                    child: const Icon(Icons.description, color: Colors.blue),
                  ),
                  title: Text(complaint['title'] ?? 'No Title'),
                  subtitle: Text('Ticket: ${complaint['ticketNumber'] ?? 'N/A'}'),
                  trailing: Chip(
                    label: Text(complaint['status'] ?? 'N/A'),
                    backgroundColor: Colors.blue.shade100,
                  ),
                  onTap: () {
                    print('🖱️ [FLUTTER] Complaint tapped: ${complaint['ticketNumber']}');
                    // Show complaint details
                  },
                ),
              );
            }).toList(),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      drawer: AppSidebarBuilder.buildStaffSidebar(context: context),
      appBar: AppBar(
        title: const Text('Staff Dashboard'),
        backgroundColor: AppColors.primary,
        leading: Builder(
          builder: (context) => IconButton(
            icon: const Icon(Icons.menu),
            onPressed: () => Scaffold.of(context).openDrawer(),
          ),
        ),
      ),
      body: _getBodyForIndex(_currentIndex),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentIndex,
        onTap: (index) {
          setState(() {
            _currentIndex = index;
          });
        },
        type: BottomNavigationBarType.fixed,
        selectedItemColor: AppColors.primary,
        unselectedItemColor: Colors.grey,
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.dashboard),
            label: 'Dashboard',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.article_outlined),
            label: 'News',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.person),
            label: 'Profile',
          ),
        ],
      ),
    );
  }

  Future<void> _handleLogout() async {
    print('🖱️ [FLUTTER] Logging out...');
    await StorageService.remove(AppConstants.tokenKey);
    await StorageService.remove(AppConstants.userKey);
    ApiService.setToken(null);
    print('✅ [FLUTTER] Logged out successfully');
    if (mounted) {
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (_) => const RoleSelectionScreen()),
        (route) => false,
      );
    }
  }
}

class _StatCard extends StatelessWidget {
  final String title;
  final String value;
  final IconData icon;
  final Color color;

  const _StatCard({
    required this.title,
    required this.value,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.1),
            spreadRadius: 1,
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color, size: 32),
          const SizedBox(height: 12),
          Text(
            value,
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            title,
            style: const TextStyle(
              fontSize: 12,
              color: Colors.grey,
            ),
          ),
        ],
      ),
    );
  }
}

