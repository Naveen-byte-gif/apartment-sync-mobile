import '../../../core/imports/app_imports.dart';
import 'change_flat_status_screen.dart';
import 'visitor_logs_screen.dart';

class FlatDetailsStaffScreen extends StatefulWidget {
  final String buildingCode;
  final String buildingName;
  final int floorNumber;
  final String flatNumber;
  final Map<String, dynamic>? staffData;

  const FlatDetailsStaffScreen({
    super.key,
    required this.buildingCode,
    required this.buildingName,
    required this.floorNumber,
    required this.flatNumber,
    this.staffData,
  });

  @override
  State<FlatDetailsStaffScreen> createState() => _FlatDetailsStaffScreenState();
}

class _FlatDetailsStaffScreenState extends State<FlatDetailsStaffScreen> {
  Map<String, dynamic>? _flatData;
  bool _isLoading = true;

  bool get _canChangeFlatStatus {
    final permissions = widget.staffData?['permissions'];
    return permissions?['canChangeFlatStatus'] == true || 
           permissions?['fullAccess'] == true;
  }

  bool get _canViewVisitorHistory {
    final permissions = widget.staffData?['permissions'];
    return permissions?['canViewVisitorHistory'] == true || 
           permissions?['fullAccess'] == true;
  }

  @override
  void initState() {
    super.initState();
    _loadFlatDetails();
  }

  Future<void> _loadFlatDetails() async {
    setState(() => _isLoading = true);
    try {
      // For staff, we need to use admin endpoint but backend will check permissions
      // Alternatively, we can create a staff-specific endpoint
      final endpoint = ApiConstants.getFlatDetails(
        widget.buildingCode,
        widget.floorNumber,
        widget.flatNumber,
      );
      final response = await ApiService.get(endpoint);
      
      if (response['success'] == true) {
        setState(() {
          _flatData = response['data'];
        });
      } else {
        AppMessageHandler.showError(context, response['message'] ?? 'Failed to load flat details');
      }
    } catch (e) {
      AppMessageHandler.handleError(context, e);
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Color _getStatusColor(String status) {
    switch (status) {
      case 'Vacant':
        return Colors.grey;
      case 'Occupied':
        return AppColors.success;
      case 'Maintenance':
        return Colors.orange;
      case 'Reserved':
        return Colors.blue;
      case 'Blocked':
        return AppColors.error;
      default:
        return Colors.grey;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Flat ${widget.flatNumber}'),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _flatData == null
              ? const Center(child: Text('Flat not found'))
              : SingleChildScrollView(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Flat Info Card
                      Card(
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          'Flat ${_flatData!['flat']?['flatNumber'] ?? widget.flatNumber}',
                                          style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                        const SizedBox(height: 4),
                                        Text(
                                          'Floor ${widget.floorNumber}',
                                          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                            color: AppColors.textSecondary,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                    decoration: BoxDecoration(
                                      color: _getStatusColor(_flatData!['flat']?['status'] ?? 'Vacant').withOpacity(0.1),
                                      borderRadius: BorderRadius.circular(16),
                                      border: Border.all(
                                        color: _getStatusColor(_flatData!['flat']?['status'] ?? 'Vacant'),
                                      ),
                                    ),
                                    child: Text(
                                      _flatData!['flat']?['status'] ?? 'Vacant',
                                      style: TextStyle(
                                        color: _getStatusColor(_flatData!['flat']?['status'] ?? 'Vacant'),
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 16),
                              _InfoRow(
                                label: 'Flat Code',
                                value: _flatData!['flat']?['flatCode'] ?? 'N/A',
                              ),
                              _InfoRow(
                                label: 'Flat Type',
                                value: _flatData!['flat']?['flatType'] ?? 'N/A',
                              ),
                              if (_flatData!['flat']?['squareFeet'] != null)
                                _InfoRow(
                                  label: 'Square Feet',
                                  value: '${_flatData!['flat']?['squareFeet']} sq.ft',
                                ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      // Resident Info Card
                      if (_flatData!['flat']?['resident'] != null)
                        Card(
                          child: Padding(
                            padding: const EdgeInsets.all(16),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Resident Information',
                                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                const SizedBox(height: 12),
                                _InfoRow(
                                  label: 'Name',
                                  value: _flatData!['flat']?['resident']?['fullName'] ?? 'N/A',
                                ),
                                _InfoRow(
                                  label: 'Phone',
                                  value: _flatData!['flat']?['resident']?['phoneNumber'] ?? 'N/A',
                                ),
                                if (_flatData!['flat']?['resident']?['email'] != null)
                                  _InfoRow(
                                    label: 'Email',
                                    value: _flatData!['flat']?['resident']?['email'] ?? 'N/A',
                                  ),
                                _InfoRow(
                                  label: 'Type',
                                  value: _flatData!['flat']?['resident']?['residentType'] ?? 'N/A',
                                ),
                              ],
                            ),
                          ),
                        ),
                      const SizedBox(height: 16),
                      // Actions Card
                      Card(
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Actions',
                                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(height: 12),
                              if (_canChangeFlatStatus)
                                ListTile(
                                  leading: const Icon(Icons.edit, color: AppColors.primary),
                                  title: const Text('Change Flat Status'),
                                  trailing: const Icon(Icons.chevron_right),
                                  onTap: () {
                                    Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder: (_) => ChangeFlatStatusScreen(
                                          buildingCode: widget.buildingCode,
                                          floorNumber: widget.floorNumber,
                                          flatNumber: widget.flatNumber,
                                          currentStatus: _flatData!['flat']?['status'] ?? 'Vacant',
                                        ),
                                      ),
                                    ).then((_) => _loadFlatDetails());
                                  },
                                ),
                              if (_canViewVisitorHistory)
                                ListTile(
                                  leading: const Icon(Icons.history, color: AppColors.info),
                                  title: const Text('Visitor Logs'),
                                  subtitle: const Text('View visitor history for this flat'),
                                  trailing: const Icon(Icons.chevron_right),
                                  onTap: () {
                                    Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder: (_) => VisitorLogsScreen(
                                          buildingCode: widget.buildingCode,
                                          floorNumber: widget.floorNumber,
                                          flatNumber: widget.flatNumber,
                                        ),
                                      ),
                                    );
                                  },
                                ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  final String label;
  final String value;

  const _InfoRow({
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 100,
            child: Text(
              label,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: AppColors.textSecondary,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: AppColors.textPrimary,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

