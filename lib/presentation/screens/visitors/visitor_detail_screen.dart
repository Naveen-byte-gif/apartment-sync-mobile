import 'package:flutter/material.dart';
import '../../../core/imports/app_imports.dart';
import '../../../core/services/api_service.dart';
import '../../../core/constants/api_constants.dart';
import 'dart:convert';

class VisitorDetailScreen extends StatefulWidget {
  final String visitorId;

  const VisitorDetailScreen({super.key, required this.visitorId});

  @override
  State<VisitorDetailScreen> createState() => _VisitorDetailScreenState();
}

class _VisitorDetailScreenState extends State<VisitorDetailScreen> {
  Map<String, dynamic>? _visitor;
  bool _isLoading = true;
  Map<String, dynamic>? _user;

  @override
  void initState() {
    super.initState();
    _loadUserData();
    _loadVisitorDetails();
  }

  void _loadUserData() {
    final userJson = StorageService.getString(AppConstants.userKey);
    if (userJson != null) {
      try {
        setState(() {
          _user = jsonDecode(userJson);
        });
      } catch (e) {
        print('Error parsing user data: $e');
      }
    }
  }

  Future<void> _loadVisitorDetails() async {
    setState(() => _isLoading = true);
    try {
      final response = await ApiService.get(ApiConstants.visitorById(widget.visitorId));
      if (response['success'] == true) {
        setState(() {
          _visitor = response['data']?['visitor'];
          _isLoading = false;
        });
      } else {
        AppMessageHandler.handleResponse(context, response);
        setState(() => _isLoading = false);
      }
    } catch (e) {
      AppMessageHandler.handleError(context, e);
      setState(() => _isLoading = false);
    }
  }

  String _formatDateTime(String? dateTime) {
    if (dateTime == null) return 'Not set';
    try {
      final dt = DateTime.parse(dateTime);
      final day = dt.day.toString().padLeft(2, '0');
      final month = dt.month.toString().padLeft(2, '0');
      final year = dt.year;
      final hour = dt.hour > 12 ? dt.hour - 12 : (dt.hour == 0 ? 12 : dt.hour);
      final minute = dt.minute.toString().padLeft(2, '0');
      final period = dt.hour >= 12 ? 'PM' : 'AM';
      return '$day/$month/$year $hour:$minute $period';
    } catch (e) {
      return dateTime;
    }
  }

  Color _getStatusColor(String status) {
    switch (status.toLowerCase()) {
      case 'pending':
        return Colors.orange;
      case 'pre-approved':
        return Colors.blue;
      case 'checked in':
        return Colors.green;
      case 'checked out':
        return Colors.grey;
      case 'rejected':
        return Colors.red;
      case 'cancelled':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }

  IconData _getStatusIcon(String status) {
    switch (status.toLowerCase()) {
      case 'pending':
        return Icons.pending;
      case 'pre-approved':
        return Icons.check_circle_outline;
      case 'checked in':
        return Icons.login;
      case 'checked out':
        return Icons.logout;
      case 'rejected':
        return Icons.cancel;
      case 'cancelled':
        return Icons.cancel;
      default:
        return Icons.info;
    }
  }

  @override
  Widget build(BuildContext context) {
    final userRole = _user?['role'] ?? 'resident';
    final isResident = userRole == 'resident';

    return Scaffold(
      backgroundColor: const Color(0xFF0F1419),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'Visitor Details',
          style: TextStyle(color: Colors.white),
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: Colors.white))
          : _visitor == null
              ? const Center(
                  child: Text(
                    'Visitor not found',
                    style: TextStyle(color: Colors.white),
                  ),
                )
              : SingleChildScrollView(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Visitor Header Card
                      _buildHeaderCard(),
                      const SizedBox(height: 16),
                      
                      // Building & Flat Details Section
                      _buildSectionCard(
                        icon: Icons.location_on,
                        iconColor: Colors.orange,
                        title: 'Building & Flat Details',
                        children: [
                          _buildDetailRow('Building', _visitor!['building'] ?? 'N/A'),
                          _buildDivider(),
                          _buildDetailRow('Floor', '${_visitor!['floorNumber'] ?? 'N/A'}'),
                          _buildDivider(),
                          _buildDetailRow('Flat / Apartment Number', _visitor!['flatNumber'] ?? 'N/A'),
                          _buildDivider(),
                          _buildDetailRow('Apartment Code', _visitor!['apartmentCode'] ?? 'N/A'),
                        ],
                      ),
                      const SizedBox(height: 16),
                      
                      // Flat Owner Details Section
                      _buildSectionCard(
                        icon: Icons.home,
                        iconColor: Colors.blue,
                        title: 'Flat Owner Details',
                        children: [
                          if (_visitor!['hostResident'] != null) ...[
                            _buildDetailRow('Name', _visitor!['hostResident']['fullName'] ?? 'N/A'),
                            _buildDivider(),
                            _buildDetailRow(
                              'Contact',
                              _visitor!['hostResident']['phoneNumber'] ?? 'N/A',
                              isPhone: true,
                            ),
                            if (_visitor!['hostResident']['email'] != null) ...[
                              _buildDivider(),
                              _buildDetailRow(
                                'Email',
                                _visitor!['hostResident']['email'] ?? 'N/A',
                                isEmail: true,
                              ),
                            ],
                          ] else
                            _buildDetailRow('Owner', 'Not available', valueColor: Colors.grey),
                        ],
                      ),
                      const SizedBox(height: 16),
                      
                      // Visitor Entry Details Section
                      _buildSectionCard(
                        icon: Icons.access_time,
                        iconColor: Colors.green,
                        title: 'Visitor Entry Details',
                        children: [
                          // Login Time
                          _buildDetailRow(
                            'Login Time',
                            _visitor!['checkInTime'] != null
                                ? _formatDateTime(_visitor!['checkInTime'])
                                : _visitor!['entryDate'] != null
                                    ? _formatDateTime(_visitor!['entryDate'])
                                    : 'Not set',
                            valueColor: Colors.blue,
                          ),
                          // Exit Time
                          if (_visitor!['checkOutTime'] != null) ...[
                            _buildDivider(),
                            _buildDetailRow(
                              'Exit Time',
                              _formatDateTime(_visitor!['checkOutTime']),
                              valueColor: Colors.red,
                            ),
                          ],
                        ],
                      ),
                      const SizedBox(height: 16),
                      
                      // Entry Creation Details Section
                      _buildSectionCard(
                        icon: Icons.person_add,
                        iconColor: Colors.purple,
                        title: 'Entry Creation Details',
                        children: [
                          if (_visitor!['createdBy'] != null) ...[
                            _buildDetailRow(
                              'Created By',
                              _visitor!['createdBy']['fullName'] ?? 'N/A',
                            ),
                            _buildDivider(),
                            _buildDetailRow(
                              'Role',
                              _visitor!['createdBy']['role'] != null
                                  ? _visitor!['createdBy']['role'].toString().toUpperCase()
                                  : 'N/A',
                            ),
                            if (_visitor!['createdBy']['phoneNumber'] != null) ...[
                              _buildDivider(),
                              _buildDetailRow(
                                'Contact',
                                _visitor!['createdBy']['phoneNumber'] ?? 'N/A',
                                isPhone: true,
                              ),
                            ],
                            if (_visitor!['createdBy']['email'] != null) ...[
                              _buildDivider(),
                              _buildDetailRow(
                                'Email',
                                _visitor!['createdBy']['email'] ?? 'N/A',
                                isEmail: true,
                              ),
                            ],
                            _buildDivider(),
                            _buildDetailRow(
                              'Entry Created At',
                              _visitor!['entryDate'] != null
                                  ? _formatDateTime(_visitor!['entryDate'])
                                  : 'Not set',
                              valueColor: Colors.blue,
                            ),
                          ] else
                            _buildDetailRow(
                              'Created By',
                              'Not available',
                              valueColor: Colors.grey,
                            ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      // Security / Staff Details Section
                      _buildSectionCard(
                        icon: Icons.security,
                        iconColor: Colors.orange,
                        title: 'Security / Staff Details',
                        children: [
                          if (_visitor!['checkedInBy'] != null) ...[
                            _buildDetailRow(
                              'Recorded Entry By',
                              _visitor!['checkedInBy']['fullName'] ?? 'N/A',
                            ),
                            if (_visitor!['checkedInBy']['role'] != null) ...[
                              _buildDivider(),
                              _buildDetailRow(
                                'Role',
                                _visitor!['checkedInBy']['role'].toString().toUpperCase(),
                              ),
                            ],
                          ] else
                            _buildDetailRow(
                              'Recorded Entry By',
                              'Not available',
                              valueColor: Colors.grey,
                            ),
                          if (_visitor!['checkedOutBy'] != null) ...[
                            _buildDivider(),
                            _buildDetailRow(
                              'Recorded Exit By',
                              _visitor!['checkedOutBy']['fullName'] ?? 'N/A',
                            ),
                            if (_visitor!['checkedOutBy']['role'] != null) ...[
                              _buildDivider(),
                              _buildDetailRow(
                                'Role',
                                _visitor!['checkedOutBy']['role'].toString().toUpperCase(),
                              ),
                            ],
                          ],
                        ],
                      ),
                      const SizedBox(height: 16),
                      
                      // Visitor Information Section
                      _buildSectionCard(
                        icon: Icons.person,
                        iconColor: Colors.teal,
                        title: 'Visitor Information',
                        children: [
                          _buildDetailRow('Name', _visitor!['visitorName'] ?? 'N/A'),
                          _buildDivider(),
                          _buildDetailRow('Type', _visitor!['visitorType'] ?? 'Guest'),
                          _buildDivider(),
                          _buildDetailRow(
                            'Phone',
                            _visitor!['phoneNumber'] ?? 'N/A',
                            isPhone: true,
                          ),
                          if (_visitor!['email'] != null) ...[
                            _buildDivider(),
                            _buildDetailRow(
                              'Email',
                              _visitor!['email'] ?? 'N/A',
                              isEmail: true,
                            ),
                          ],
                          if (_visitor!['purpose'] != null) ...[
                            _buildDivider(),
                            _buildDetailRow('Purpose', _visitor!['purpose'] ?? 'N/A'),
                          ],
                          if (_visitor!['vehicleNumber'] != null) ...[
                            _buildDivider(),
                            _buildDetailRow('Vehicle Number', _visitor!['vehicleNumber'] ?? 'N/A'),
                          ],
                        ],
                      ),
                      
                      // Exit Button (for Staff/Admin only, when visitor is checked in)
                      if (!isResident && 
                          _visitor!['checkOutTime'] == null && 
                          _visitor!['checkInTime'] != null) ...[
                        const SizedBox(height: 24),
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton.icon(
                            onPressed: () => _showExitConfirmationDialog(),
                            icon: const Icon(Icons.exit_to_app, size: 24),
                            label: const Text(
                              'Exit',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.red,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 18),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                              elevation: 4,
                            ),
                          ),
                        ),
                      ],
                      const SizedBox(height: 24),
                    ],
                  ),
                ),
    );
  }

  Widget _buildHeaderCard() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFF1A2332),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: Colors.blue.withOpacity(0.3),
          width: 2,
        ),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.blue.withOpacity(0.2),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(
              Icons.person,
              color: Colors.blue,
              size: 36,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _visitor!['visitorName'] ?? 'Unknown Visitor',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  '${_visitor!['building'] ?? ''} - ${_visitor!['flatNumber'] ?? ''}',
                  style: TextStyle(
                    color: Colors.white70,
                    fontSize: 14,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionCard({
    required IconData icon,
    required Color iconColor,
    required String title,
    required List<Widget> children,
  }) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFF1A2332),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: iconColor.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, color: iconColor, size: 24),
              ),
              const SizedBox(width: 12),
              Text(
                title,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          ...children,
        ],
      ),
    );
  }

  Widget _buildDetailRow(
    String label,
    String value, {
    Color? valueColor,
    bool isPhone = false,
    bool isEmail = false,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 140,
            child: Text(
              label,
              style: TextStyle(
                color: Colors.white70,
                fontSize: 14,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          Expanded(
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    value,
                    style: TextStyle(
                      color: valueColor ?? Colors.white,
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                if (isPhone)
                  IconButton(
                    icon: const Icon(Icons.phone, size: 18, color: Colors.green),
                    onPressed: () {
                      // TODO: Implement phone call
                    },
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                  ),
                if (isEmail)
                  IconButton(
                    icon: const Icon(Icons.email, size: 18, color: Colors.blue),
                    onPressed: () {
                      // TODO: Implement email
                    },
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDivider() {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Divider(
        color: Colors.white.withOpacity(0.1),
        height: 1,
      ),
    );
  }

  Future<void> _showExitConfirmationDialog() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1A2332),
        title: const Text(
          'Exit Visitor',
          style: TextStyle(color: Colors.white),
        ),
        content: const Text(
          'Are you sure you want to mark this visitor as exited? This will record the exit time.',
          style: TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text(
              'Cancel',
              style: TextStyle(color: Colors.white70),
            ),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            child: const Text('Exit'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await _checkOutVisitor();
    }
  }

  Future<void> _checkOutVisitor() async {
    try {
      setState(() => _isLoading = true);
      final response = await ApiService.post(
        ApiConstants.visitorCheckOut(widget.visitorId),
        {},
      );

      if (response['success'] == true) {
        AppMessageHandler.showSuccess(context, 'Visitor exited successfully');
        _loadVisitorDetails();
      } else {
        AppMessageHandler.handleResponse(context, response);
      }
    } catch (e) {
      AppMessageHandler.handleError(context, e);
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }
}

