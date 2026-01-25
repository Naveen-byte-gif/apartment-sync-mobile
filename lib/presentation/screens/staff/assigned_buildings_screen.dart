import '../../../core/imports/app_imports.dart';
import 'building_dashboard_screen.dart';
import 'dart:convert';

class AssignedBuildingsScreen extends StatefulWidget {
  const AssignedBuildingsScreen({super.key});

  @override
  State<AssignedBuildingsScreen> createState() =>
      _AssignedBuildingsScreenState();
}

class _AssignedBuildingsScreenState extends State<AssignedBuildingsScreen> {
  List<Map<String, dynamic>> _assignedBuildings = [];
  bool _isLoading = true;
  Map<String, dynamic>? _staffData;

  @override
  void initState() {
    super.initState();
    _loadAssignedBuildings();
  }

  Future<void> _loadAssignedBuildings() async {
    setState(() => _isLoading = true);
    try {
      // Get staff profile with assigned buildings
      final staffResponse = await ApiService.get(ApiConstants.staffDashboard);
      if (staffResponse['success'] == true) {
        final staff = staffResponse['data']?['staff'];
        setState(() {
          _staffData = staff;
          final assignedBuildings = staff?['assignedBuildings'] ?? [];
          _assignedBuildings = List<Map<String, dynamic>>.from(
            assignedBuildings,
          );
        });

        // Check if staff is active and onboarding is completed
        if (staff?['isActive'] != true) {
          AppMessageHandler.showError(
            context,
            'Your staff account is inactive. Please contact admin.',
          );
          return;
        }

        // Show warning if onboarding is incomplete, but allow access
        if (staff?['onboardingIncomplete'] == true) {
          // Show info message instead of error - they can still access
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(
                  '⚠️ Your onboarding is not completed. Some features may be limited.',
                ),
                backgroundColor: Colors.orange,
                duration: Duration(seconds: 4),
              ),
            );
          }
        }

        if (_assignedBuildings.isEmpty) {
          AppMessageHandler.showError(
            context,
            'No buildings assigned. Please contact admin.',
          );
          return;
        }

        // Auto-navigate if only one building
        if (_assignedBuildings.length == 1 && mounted) {
          _navigateToBuilding(_assignedBuildings.first);
        }
      }
    } catch (e) {
      AppMessageHandler.handleError(context, e);
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  void _navigateToBuilding(Map<String, dynamic> building) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => BuildingDashboardScreen(
          buildingCode: building['buildingCode'],
          buildingName: building['buildingName'] ?? building['buildingCode'],
          staffData: _staffData,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Select Building'),
        automaticallyImplyLeading: false,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _assignedBuildings.isEmpty
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(
                    Icons.apartment_outlined,
                    size: 64,
                    color: Colors.grey,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'No buildings assigned',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Please contact admin to assign buildings',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
            )
          : RefreshIndicator(
              onRefresh: _loadAssignedBuildings,
              child: ListView.builder(
                padding: const EdgeInsets.all(16),
                itemCount: _assignedBuildings.length,
                itemBuilder: (context, index) {
                  final building = _assignedBuildings[index];
                  return Card(
                    margin: const EdgeInsets.only(bottom: 12),
                    child: ListTile(
                      leading: Container(
                        width: 50,
                        height: 50,
                        decoration: BoxDecoration(
                          color: AppColors.primary.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Icon(
                          Icons.apartment,
                          color: AppColors.primary,
                        ),
                      ),
                      title: Text(
                        building['buildingName'] ?? building['buildingCode'],
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                      subtitle: Text(
                        building['buildingCode'] ?? '',
                        style: TextStyle(color: AppColors.textSecondary),
                      ),
                      trailing: const Icon(Icons.chevron_right),
                      onTap: () => _navigateToBuilding(building),
                    ),
                  );
                },
              ),
            ),
    );
  }
}
