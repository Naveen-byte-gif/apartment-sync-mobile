import '../../../core/imports/app_imports.dart';
import 'create_resident_from_flat_screen.dart';

class FlatDetailsScreen extends StatefulWidget {
  final String buildingCode;
  final int floorNumber;
  final String flatNumber;

  const FlatDetailsScreen({
    super.key,
    required this.buildingCode,
    required this.floorNumber,
    required this.flatNumber,
  });

  @override
  State<FlatDetailsScreen> createState() => _FlatDetailsScreenState();
}

class _FlatDetailsScreenState extends State<FlatDetailsScreen> {
  Map<String, dynamic>? _flatData;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadFlatDetails();
  }

  Future<void> _loadFlatDetails() async {
    setState(() => _isLoading = true);
    try {
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
      case 'Occupied':
        return AppColors.success;
      case 'Vacant':
        return Colors.grey;
      case 'Maintenance':
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
                      // Building Info Card
                      Card(
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Building Information',
                                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(height: 12),
                              _InfoRow(
                                label: 'Building Name',
                                value: _flatData!['building']?['name'] ?? 'N/A',
                              ),
                              _InfoRow(
                                label: 'Building Code',
                                value: _flatData!['building']?['code'] ?? 'N/A',
                              ),
                              if (_flatData!['building']?['address'] != null)
                                _InfoRow(
                                  label: 'Address',
                                  value: _formatAddress(_flatData!['building']?['address']),
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
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Text(
                                      'Resident Information',
                                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                    if (_flatData!['flat']?['resident']?['isPrimaryResident'] == true)
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                        decoration: BoxDecoration(
                                          color: AppColors.primary.withOpacity(0.1),
                                          borderRadius: BorderRadius.circular(8),
                                        ),
                                        child: const Text(
                                          'Primary',
                                          style: TextStyle(
                                            color: AppColors.primary,
                                            fontWeight: FontWeight.bold,
                                            fontSize: 10,
                                          ),
                                        ),
                                      ),
                                  ],
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
                                _InfoRow(
                                  label: 'Status',
                                  value: _flatData!['flat']?['resident']?['status'] ?? 'N/A',
                                ),
                              ],
                            ),
                          ),
                        )
                      else
                        Card(
                          child: Padding(
                            padding: const EdgeInsets.all(16),
                            child: Column(
                              children: [
                                const Icon(
                                  Icons.person_outline,
                                  size: 48,
                                  color: Colors.grey,
                                ),
                                const SizedBox(height: 12),
                                Text(
                                  'No Resident',
                                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                    color: Colors.grey,
                                  ),
                                ),
                                const SizedBox(height: 16),
                                ElevatedButton.icon(
                                  onPressed: () {
                                    Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder: (_) => CreateResidentFromFlatScreen(
                                          buildingCode: widget.buildingCode,
                                          floorNumber: widget.floorNumber,
                                          flatNumber: widget.flatNumber,
                                          flatType: _flatData!['flat']?['flatType'] ?? '',
                                        ),
                                      ),
                                    ).then((_) => _loadFlatDetails());
                                  },
                                  icon: const Icon(Icons.person_add),
                                  label: const Text('Add Resident'),
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

  String _formatAddress(Map<String, dynamic>? address) {
    if (address == null) return 'N/A';
    final parts = [
      address['street'],
      address['city'],
      address['state'],
      address['pincode'],
    ].where((part) => part != null && part.toString().isNotEmpty).toList();
    return parts.join(', ');
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

