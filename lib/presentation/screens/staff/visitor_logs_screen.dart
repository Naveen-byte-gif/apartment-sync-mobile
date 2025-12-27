import '../../../core/imports/app_imports.dart';

class VisitorLogsScreen extends StatefulWidget {
  final String? buildingCode;
  final int? floorNumber;
  final String? flatNumber;

  const VisitorLogsScreen({
    super.key,
    this.buildingCode,
    this.floorNumber,
    this.flatNumber,
  });

  @override
  State<VisitorLogsScreen> createState() => _VisitorLogsScreenState();
}

class _VisitorLogsScreenState extends State<VisitorLogsScreen> {
  List<Map<String, dynamic>> _visitors = [];
  bool _isLoading = true;
  String? _selectedFilter;
  DateTime? _selectedDate;

  final List<String> _filterOptions = ['All', 'Today', 'This Week', 'This Month'];

  @override
  void initState() {
    super.initState();
    _loadVisitorLogs();
  }

  Future<void> _loadVisitorLogs() async {
    setState(() => _isLoading = true);
    try {
      String endpoint = ApiConstants.visitors;
      
      // Add filters if provided
      final queryParams = <String, String>{};
      if (widget.buildingCode != null) {
        queryParams['buildingCode'] = widget.buildingCode!;
      }
      if (widget.floorNumber != null) {
        queryParams['floorNumber'] = widget.floorNumber.toString();
      }
      if (widget.flatNumber != null) {
        queryParams['flatNumber'] = widget.flatNumber!;
      }
      
      if (queryParams.isNotEmpty) {
        final uri = Uri.parse(endpoint).replace(queryParameters: queryParams);
        endpoint = uri.toString();
      }

      final response = await ApiService.get(endpoint);
      
      if (response['success'] == true) {
        final visitors = response['data']?['visitors'] ?? response['data'] ?? [];
        setState(() {
          _visitors = List<Map<String, dynamic>>.from(visitors);
        });
      }
    } catch (e) {
      AppMessageHandler.handleError(context, e);
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  String _formatDateTime(String? dateTime) {
    if (dateTime == null) return 'N/A';
    try {
      final dt = DateTime.parse(dateTime);
      // Format: DD MMM YYYY, HH:MM AM/PM
      final months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
      final hour = dt.hour > 12 ? dt.hour - 12 : (dt.hour == 0 ? 12 : dt.hour);
      final ampm = dt.hour >= 12 ? 'PM' : 'AM';
      final minute = dt.minute.toString().padLeft(2, '0');
      return '${dt.day} ${months[dt.month - 1]} ${dt.year}, $hour:$minute $ampm';
    } catch (e) {
      return dateTime;
    }
  }

  Color _getStatusColor(String status) {
    switch (status) {
      case 'Checked In':
        return AppColors.success;
      case 'Checked Out':
        return Colors.grey;
      case 'Pending':
        return Colors.orange;
      case 'Pre-Approved':
        return Colors.blue;
      default:
        return Colors.grey;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          widget.flatNumber != null
              ? 'Visitor Logs - Flat ${widget.flatNumber}'
              : 'Visitor Logs',
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.filter_list),
            onPressed: () {
              // Show filter dialog
              showDialog(
                context: context,
                builder: (context) => AlertDialog(
                  title: const Text('Filter Visitors'),
                  content: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      ListTile(
                        title: const Text('All'),
                        leading: Radio<String>(
                          value: 'All',
                          groupValue: _selectedFilter,
                          onChanged: (value) {
                            setState(() => _selectedFilter = value);
                            Navigator.pop(context);
                            _loadVisitorLogs();
                          },
                        ),
                      ),
                      ListTile(
                        title: const Text('Today'),
                        leading: Radio<String>(
                          value: 'Today',
                          groupValue: _selectedFilter,
                          onChanged: (value) {
                            setState(() => _selectedFilter = value);
                            Navigator.pop(context);
                            _loadVisitorLogs();
                          },
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadVisitorLogs,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _visitors.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.history, size: 64, color: Colors.grey),
                      const SizedBox(height: 16),
                      Text(
                        'No visitor logs found',
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                    ],
                  ),
                )
              : RefreshIndicator(
                  onRefresh: _loadVisitorLogs,
                  child: ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: _visitors.length,
                    itemBuilder: (context, index) {
                      final visitor = _visitors[index];
                      final status = visitor['status'] ?? 'Pending';
                      
                      return Card(
                        margin: const EdgeInsets.only(bottom: 12),
                        child: ListTile(
                          leading: CircleAvatar(
                            backgroundColor: _getStatusColor(status).withOpacity(0.1),
                            child: Icon(
                              Icons.person,
                              color: _getStatusColor(status),
                            ),
                          ),
                          title: Text(
                            visitor['visitorName'] ?? 'Unknown',
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                          subtitle: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              if (visitor['flatNumber'] != null)
                                Text('Flat: ${visitor['flatNumber']}'),
                              if (visitor['purpose'] != null)
                                Text('Purpose: ${visitor['purpose']}'),
                              if (visitor['checkInTime'] != null)
                                Text('Time: ${_formatDateTime(visitor['checkInTime'])}'),
                            ],
                          ),
                          trailing: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: _getStatusColor(status).withOpacity(0.1),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Text(
                              status,
                              style: TextStyle(
                                color: _getStatusColor(status),
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                          isThreeLine: true,
                        ),
                      );
                    },
                  ),
                ),
    );
  }
}

