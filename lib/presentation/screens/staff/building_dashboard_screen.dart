import '../../../core/imports/app_imports.dart';
import 'floors_list_screen.dart';
import 'visitor_entry_screen.dart';
import 'visitor_logs_screen.dart';

class BuildingDashboardScreen extends StatefulWidget {
  final String buildingCode;
  final String buildingName;
  final Map<String, dynamic>? staffData;

  const BuildingDashboardScreen({
    super.key,
    required this.buildingCode,
    required this.buildingName,
    this.staffData,
  });

  @override
  State<BuildingDashboardScreen> createState() => _BuildingDashboardScreenState();
}

class _BuildingDashboardScreenState extends State<BuildingDashboardScreen> {
  Map<String, dynamic>? _buildingData;
  Map<String, dynamic>? _permissions;
  bool _isLoading = true;

  bool get _canChangeFlatStatus {
    final perms = _permissions ?? widget.staffData?['permissions'];
    return perms?['canChangeFlatStatus'] == true || 
           perms?['fullAccess'] == true;
  }

  bool get _canLogVisitorEntry {
    final perms = _permissions ?? widget.staffData?['permissions'];
    return perms?['canLogVisitorEntry'] == true || 
           perms?['fullAccess'] == true;
  }

  bool get _canViewVisitorHistory {
    final perms = _permissions ?? widget.staffData?['permissions'];
    return perms?['canViewVisitorHistory'] == true || 
           perms?['fullAccess'] == true;
  }

  @override
  void initState() {
    super.initState();
    _loadBuildingDetails();
  }

  Future<void> _loadBuildingDetails() async {
    setState(() => _isLoading = true);
    try {
      // Use staff-specific endpoint that checks permissions
      final endpoint = ApiConstants.addBuildingCode(
        ApiConstants.staffBuildingDetails,
        widget.buildingCode,
      );
      final response = await ApiService.get(endpoint);
      
      if (response['success'] == true) {
        setState(() {
          _buildingData = response['data']?['building'];
          // Update permissions from response if available
          if (response['data']?['permissions'] != null) {
            _permissions = response['data']?['permissions'];
          }
        });
      } else {
        // Check if it's a permission/access error
        final message = response['message']?.toString().toLowerCase() ?? '';
        if (message.contains('access') || message.contains('permission') || message.contains('unauthorized')) {
          AppMessageHandler.showError(context, response['message'] ?? 'Access denied');
          if (mounted) {
            Navigator.pop(context); // Go back if access denied
          }
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.buildingName),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Building Info Card
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            widget.buildingName,
                            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Code: ${widget.buildingCode}',
                            style: Theme.of(context).textTheme.bodyMedium,
                          ),
                          if (_buildingData?['statistics'] != null) ...[
                            const SizedBox(height: 12),
                            Row(
                              children: [
                                _StatChip(
                                  label: 'Total Flats',
                                  value: '${_buildingData!['statistics']['totalFlats'] ?? 0}',
                                  color: AppColors.primary,
                                ),
                                const SizedBox(width: 8),
                                _StatChip(
                                  label: 'Occupied',
                                  value: '${_buildingData!['statistics']['occupiedFlats'] ?? 0}',
                                  color: AppColors.success,
                                ),
                                const SizedBox(width: 8),
                                _StatChip(
                                  label: 'Vacant',
                                  value: '${_buildingData!['statistics']['vacantFlats'] ?? 0}',
                                  color: Colors.grey,
                                ),
                              ],
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
                  // Action Cards
                  Text(
                    'Quick Actions',
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 12),
                  GridView.count(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    crossAxisCount: 2,
                    crossAxisSpacing: 12,
                    mainAxisSpacing: 12,
                    childAspectRatio: 1.2,
                    children: [
                      _ActionCard(
                        title: 'Floors',
                        icon: Icons.layers,
                        color: AppColors.primary,
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => FloorsListScreen(
                                buildingCode: widget.buildingCode,
                                buildingName: widget.buildingName,
                                staffData: widget.staffData,
                              ),
                            ),
                          );
                        },
                      ),
                      if (_canLogVisitorEntry)
                        _ActionCard(
                          title: 'Visitor Entry',
                          icon: Icons.person_add,
                          color: AppColors.success,
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => VisitorEntryScreen(
                                  buildingCode: widget.buildingCode,
                                  buildingName: widget.buildingName,
                                ),
                              ),
                            );
                          },
                        ),
                      if (_canViewVisitorHistory)
                        _ActionCard(
                          title: 'Visitor Logs',
                          icon: Icons.history,
                          color: AppColors.info,
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => VisitorLogsScreen(
                                  buildingCode: widget.buildingCode,
                                ),
                              ),
                            );
                          },
                        ),
                    ],
                  ),
                ],
              ),
            ),
    );
  }
}

class _StatChip extends StatelessWidget {
  final String label;
  final String value;
  final Color color;

  const _StatChip({
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            '$label: ',
            style: TextStyle(
              color: color,
              fontWeight: FontWeight.w500,
              fontSize: 12,
            ),
          ),
          Text(
            value,
            style: TextStyle(
              color: color,
              fontWeight: FontWeight.bold,
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }
}

class _ActionCard extends StatelessWidget {
  final String title;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;

  const _ActionCard({
    required this.title,
    required this.icon,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 40, color: color),
              const SizedBox(height: 8),
              Text(
                title,
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

