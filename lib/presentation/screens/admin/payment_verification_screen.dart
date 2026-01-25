import 'package:flutter/material.dart';
import '../../../core/imports/app_imports.dart';
import '../../../data/models/payment_data.dart';

class PaymentVerificationScreen extends StatefulWidget {
  const PaymentVerificationScreen({super.key});

  @override
  State<PaymentVerificationScreen> createState() =>
      _PaymentVerificationScreenState();
}

class _PaymentVerificationScreenState extends State<PaymentVerificationScreen> {
  List<PaymentData> _payments = [];
  bool _isLoading = true;
  String? _selectedStatus;

  @override
  void initState() {
    super.initState();
    _loadPayments();
  }

  Future<void> _loadPayments() async {
    setState(() => _isLoading = true);
    try {
      String endpoint = ApiConstants.payments;
      if (_selectedStatus != null) {
        endpoint += '?status=$_selectedStatus';
      }

      final response = await ApiService.get(endpoint);
      if (response['success'] == true) {
        final paymentsData = response['data']?['payments'] ?? [];
        setState(() {
          _payments = (paymentsData as List)
              .map((item) => PaymentData.fromJson(item))
              .toList();
          _isLoading = false;
        });
      } else {
        AppMessageHandler.handleError(
          context,
          response['message'] ?? 'Failed to load payments',
        );
        setState(() => _isLoading = false);
      }
    } catch (e) {
      AppMessageHandler.handleError(context, e);
      setState(() => _isLoading = false);
    }
  }

  Future<void> _verifyPayment(
    String paymentId,
    String action, {
    String? reason,
  }) async {
    try {
      final response = await ApiService.put(
        ApiConstants.verifyPayment(paymentId),
        {'action': action, 'rejectionReason': reason},
      );

      if (response['success'] == true) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Payment ${action == 'approve' ? 'approved' : 'rejected'} successfully',
            ),
            backgroundColor: AppColors.success,
          ),
        );
        _loadPayments();
      } else {
        AppMessageHandler.handleError(
          context,
          response['message'] ?? 'Failed to verify payment',
        );
      }
    } catch (e) {
      AppMessageHandler.handleError(context, e);
    }
  }

  void _showRejectDialog(PaymentData payment) {
    final reasonController = TextEditingController();
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Reject Payment'),
        content: TextField(
          controller: reasonController,
          decoration: const InputDecoration(
            labelText: 'Rejection Reason *',
            hintText: 'Enter reason for rejection',
          ),
          maxLines: 3,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              if (reasonController.text.trim().isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Please enter rejection reason'),
                  ),
                );
                return;
              }
              Navigator.pop(context);
              _verifyPayment(
                payment.id,
                'reject',
                reason: reasonController.text.trim(),
              );
            },
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.error),
            child: const Text('Reject'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Payment Verification'),
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
      ),
      body: Column(
        children: [
          // Filter chips
          Container(
            padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  _FilterChip(
                    label: 'All',
                    isSelected: _selectedStatus == null,
                    onTap: () {
                      setState(() => _selectedStatus = null);
                      _loadPayments();
                    },
                  ),
                  const SizedBox(width: 8),
                  _FilterChip(
                    label: 'Pending',
                    isSelected: _selectedStatus == 'pending_verification',
                    onTap: () {
                      setState(() => _selectedStatus = 'pending_verification');
                      _loadPayments();
                    },
                  ),
                  const SizedBox(width: 8),
                  _FilterChip(
                    label: 'Approved',
                    isSelected: _selectedStatus == 'approved',
                    onTap: () {
                      setState(() => _selectedStatus = 'approved');
                      _loadPayments();
                    },
                  ),
                  const SizedBox(width: 8),
                  _FilterChip(
                    label: 'Rejected',
                    isSelected: _selectedStatus == 'rejected',
                    onTap: () {
                      setState(() => _selectedStatus = 'rejected');
                      _loadPayments();
                    },
                  ),
                ],
              ),
            ),
          ),
          // Payment list
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _payments.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.payment,
                          size: 64,
                          color: AppColors.textLight,
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'No payments found',
                          style: TextStyle(color: AppColors.textSecondary),
                        ),
                      ],
                    ),
                  )
                : RefreshIndicator(
                    onRefresh: _loadPayments,
                    child: ListView.builder(
                      padding: const EdgeInsets.all(16),
                      itemCount: _payments.length,
                      itemBuilder: (context, index) {
                        return _PaymentCard(
                          payment: _payments[index],
                          onApprove: () =>
                              _verifyPayment(_payments[index].id, 'approve'),
                          onReject: () => _showRejectDialog(_payments[index]),
                        );
                      },
                    ),
                  ),
          ),
        ],
      ),
    );
  }
}

class _FilterChip extends StatelessWidget {
  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  const _FilterChip({
    required this.label,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.primary : AppColors.surface,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected ? AppColors.primary : AppColors.border,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: isSelected ? Colors.white : AppColors.textPrimary,
            fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
          ),
        ),
      ),
    );
  }
}

class _PaymentCard extends StatelessWidget {
  final PaymentData payment;
  final VoidCallback onApprove;
  final VoidCallback onReject;

  const _PaymentCard({
    required this.payment,
    required this.onApprove,
    required this.onReject,
  });

  Color _getStatusColor(String status) {
    switch (status.toLowerCase()) {
      case 'approved':
        return AppColors.success;
      case 'rejected':
        return AppColors.error;
      case 'pending_verification':
        return AppColors.warning;
      default:
        return AppColors.textLight;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        "${payment.invoiceNumber}",
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '₹${payment.amount.toStringAsFixed(2)}',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: AppColors.primary,
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: _getStatusColor(payment.status).withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    payment.status.replaceAll('_', ' ').toUpperCase(),
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                      color: _getStatusColor(payment.status),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            _InfoRow(label: 'Purpose', value: payment.paymentPurpose),
            _InfoRow(
              label: 'Date',
              value:
                  '${payment.paymentDate.day}/${payment.paymentDate.month}/${payment.paymentDate.year}',
            ),
            if (payment.upiReferenceId != null)
              _InfoRow(label: 'UPI Ref ID', value: payment.upiReferenceId!),
            if (payment.rejectionReason != null) ...[
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.error.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    Icon(Icons.error_outline, color: AppColors.error, size: 20),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Reason: ${payment.rejectionReason}',
                        style: TextStyle(color: AppColors.error, fontSize: 12),
                      ),
                    ),
                  ],
                ),
              ),
            ],
            if (payment.status == 'pending_verification') ...[
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: onReject,
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppColors.error,
                        side: const BorderSide(color: AppColors.error),
                      ),
                      child: const Text('Reject'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: onApprove,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.success,
                      ),
                      child: const Text('Approve'),
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  final String label;
  final String value;

  const _InfoRow({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        children: [
          SizedBox(
            width: 80,
            child: Text(
              label,
              style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
            ),
          ),
          Text(
            value,
            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
          ),
        ],
      ),
    );
  }
}
