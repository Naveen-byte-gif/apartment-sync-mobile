import '../../../core/imports/app_imports.dart';

class ChangeFlatStatusScreen extends StatefulWidget {
  final String buildingCode;
  final int floorNumber;
  final String flatNumber;
  final String currentStatus;

  const ChangeFlatStatusScreen({
    super.key,
    required this.buildingCode,
    required this.floorNumber,
    required this.flatNumber,
    required this.currentStatus,
  });

  @override
  State<ChangeFlatStatusScreen> createState() => _ChangeFlatStatusScreenState();
}

class _ChangeFlatStatusScreenState extends State<ChangeFlatStatusScreen> {
  final _formKey = GlobalKey<FormState>();
  final _reasonController = TextEditingController();
  final _remarksController = TextEditingController();
  
  String? _selectedNewStatus;
  DateTime? _effectiveDate;
  bool _isLoading = false;

  final List<String> _validStatuses = ['Vacant', 'Reserved', 'Occupied', 'Maintenance', 'Blocked'];

  // Valid transitions based on current status
  List<String> get _allowedTransitions {
    switch (widget.currentStatus) {
      case 'Vacant':
        return ['Reserved', 'Blocked'];
      case 'Reserved':
        return ['Occupied', 'Vacant', 'Blocked'];
      case 'Occupied':
        return ['Vacant', 'Maintenance', 'Blocked'];
      case 'Maintenance':
        return ['Vacant', 'Occupied', 'Blocked'];
      case 'Blocked':
        return ['Vacant']; // Only admin can unblock
      default:
        return [];
    }
  }

  @override
  void dispose() {
    _reasonController.dispose();
    _remarksController.dispose();
    super.dispose();
  }

  Future<void> _changeStatus() async {
    if (!_formKey.currentState!.validate()) return;
    if (_selectedNewStatus == null) {
      AppMessageHandler.showError(context, 'Please select a new status');
      return;
    }

    // Show confirmation dialog
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Confirm Status Change'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Are you sure you want to change the flat status?'),
            const SizedBox(height: 12),
            Text('Old Status: ${widget.currentStatus}'),
            Text('New Status: $_selectedNewStatus'),
            if (_reasonController.text.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text('Reason: ${_reasonController.text}'),
              ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Confirm'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    setState(() => _isLoading = true);

    try {
      final endpoint = ApiConstants.changeFlatStatus(
        widget.buildingCode,
        widget.floorNumber,
        widget.flatNumber,
      );

      final response = await ApiService.put(endpoint, {
        'newStatus': _selectedNewStatus,
        'reason': _reasonController.text.trim(),
        'effectiveDate': _effectiveDate?.toIso8601String(),
        'remarks': _remarksController.text.trim(),
      });

      if (mounted) {
        final statusCode = response['_statusCode'] as int?;
        AppMessageHandler.handleResponse(
          context,
          response,
          statusCode: statusCode,
          showDialog: true,
          onSuccess: () {
            Navigator.pop(context, true); // Return success
          },
        );
      }
    } catch (e) {
      if (mounted) {
        AppMessageHandler.handleError(context, e);
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _selectDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (picked != null) {
      setState(() => _effectiveDate = picked);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Change Flat Status'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Current Status Card
              Card(
                color: AppColors.info.withOpacity(0.1),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    children: [
                      const Icon(Icons.info_outline, color: AppColors.info),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Current Status',
                              style: TextStyle(
                                fontSize: 12,
                                color: AppColors.textSecondary,
                              ),
                            ),
                            Text(
                              widget.currentStatus,
                              style: const TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 24),
              // New Status Dropdown
              Text(
                'New Status *',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              DropdownButtonFormField<String>(
                value: _selectedNewStatus,
                decoration: const InputDecoration(
                  labelText: 'Select New Status',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.arrow_drop_down_circle),
                ),
                items: _allowedTransitions.map((status) {
                  return DropdownMenuItem(
                    value: status,
                    child: Text(status),
                  );
                }).toList(),
                onChanged: (value) {
                  setState(() => _selectedNewStatus = value);
                },
                validator: (value) {
                  if (value == null) {
                    return 'Please select a new status';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 24),
              // Reason Field
              Text(
                'Reason *',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              TextFormField(
                controller: _reasonController,
                decoration: const InputDecoration(
                  labelText: 'Enter reason for status change',
                  hintText: 'e.g., Maintenance required, Resident vacated',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.description),
                ),
                maxLines: 3,
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Reason is required';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              // Effective Date (Optional)
              Text(
                'Effective Date (Optional)',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              InkWell(
                onTap: _selectDate,
                child: InputDecorator(
                  decoration: const InputDecoration(
                    labelText: 'Select effective date',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.calendar_today),
                  ),
                  child: Text(
                    _effectiveDate != null
                        ? '${_effectiveDate!.day}/${_effectiveDate!.month}/${_effectiveDate!.year}'
                        : 'Not set',
                    style: TextStyle(
                      color: _effectiveDate != null
                          ? AppColors.textPrimary
                          : AppColors.textSecondary,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              // Remarks (Optional)
              Text(
                'Remarks (Optional)',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              TextFormField(
                controller: _remarksController,
                decoration: const InputDecoration(
                  labelText: 'Additional remarks',
                  hintText: 'Any additional notes',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.note),
                ),
                maxLines: 2,
              ),
              const SizedBox(height: 32),
              // Submit Button
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _isLoading ? null : _changeStatus,
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                  ),
                  child: _isLoading
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Text(
                          'Change Status',
                          style: TextStyle(fontSize: 16),
                        ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

