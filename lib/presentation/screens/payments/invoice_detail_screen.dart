import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../core/imports/app_imports.dart';
import '../../../data/models/invoice_data.dart';
import '../../../data/models/upi_config_data.dart';
import 'payment_entry_screen.dart';

class InvoiceDetailScreen extends StatefulWidget {
  final String invoiceId;

  const InvoiceDetailScreen({super.key, required this.invoiceId});

  @override
  State<InvoiceDetailScreen> createState() => _InvoiceDetailScreenState();
}

class _InvoiceDetailScreenState extends State<InvoiceDetailScreen> {
  InvoiceData? _invoice;
  UpiConfigData? _upiConfig;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadInvoice();
    _loadUpiConfig();
  }

  Future<void> _loadInvoice() async {
    try {
      final response = await ApiService.get(ApiConstants.invoiceById(widget.invoiceId));
      if (response['success'] == true) {
        setState(() {
          _invoice = InvoiceData.fromJson(response['data']?['invoice'] ?? {});
          _isLoading = false;
        });
      } else {
        AppMessageHandler.handleError(context, response['message'] ?? 'Failed to load invoice');
        setState(() => _isLoading = false);
      }
    } catch (e) {
      AppMessageHandler.handleError(context, e);
      setState(() => _isLoading = false);
    }
  }

  Future<void> _loadUpiConfig() async {
    try {
      final response = await ApiService.get(ApiConstants.publicUpiConfig);
      if (response['success'] == true) {
        setState(() {
          _upiConfig = UpiConfigData.fromJson(response['data'] ?? {});
        });
      }
    } catch (e) {
      print('Error loading UPI config: $e');
    }
  }

  Future<void> _downloadInvoicePdf() async {
    try {
      final url = Uri.parse('${ApiConstants.baseUrl}${ApiConstants.invoicePdf(widget.invoiceId)}');
      if (await canLaunchUrl(url)) {
        await launchUrl(url, mode: LaunchMode.externalNonBrowserApplication); // Forces UPI app chooser
      }
    } catch (e) {
      AppMessageHandler.handleError(context, 'Failed to download invoice');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Invoice Details'),
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _invoice == null
              ? const Center(child: Text('Invoice not found'))
              : SingleChildScrollView(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Invoice header card
                      _InvoiceHeaderCard(invoice: _invoice!),
                      const SizedBox(height: 16),
                      // Items breakdown
                      _InvoiceItemsCard(invoice: _invoice!),
                      const SizedBox(height: 16),
                      // Payment summary
                      _PaymentSummaryCard(invoice: _invoice!),
                      const SizedBox(height: 16),
                      // UPI info
                      if (_upiConfig != null) _UpiInfoCard(upiConfig: _upiConfig!),
                      const SizedBox(height: 24),
                      // Action buttons
                      if (_invoice!.status != 'paid' && _invoice!.outstandingAmount > 0)
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton.icon(
                            onPressed: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => PaymentEntryScreen(invoice: _invoice!),
                                ),
                              ).then((_) => _loadInvoice());
                            },
                            icon: const Icon(Icons.payment),
                            label: const Text('Pay via UPI'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.primary,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 16),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                          ),
                        ),
                      const SizedBox(height: 12),
                      SizedBox(
                        width: double.infinity,
                        child: OutlinedButton.icon(
                          onPressed: _downloadInvoicePdf,
                          icon: const Icon(Icons.download),
                          label: const Text('Download Invoice PDF'),
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
    );
  }
}

class _InvoiceHeaderCard extends StatelessWidget {
  final InvoiceData invoice;

  const _InvoiceHeaderCard({required this.invoice});

  @override
  Widget build(BuildContext context) {
    return Card(
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
                        invoice.invoiceNumber,
                        style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '${invoice.building} - ${invoice.flatNumber}',
                        style: TextStyle(
                          fontSize: 14,
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: _getStatusColor(invoice.status).withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    invoice.status.toUpperCase(),
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: _getStatusColor(invoice.status),
                    ),
                  ),
                ),
              ],
            ),
            const Divider(height: 24),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                _InfoItem(
                  label: 'Billing Period',
                  value: '${_formatDate(invoice.billingPeriod.startDate)} - ${_formatDate(invoice.billingPeriod.endDate)}',
                ),
                _InfoItem(
                  label: 'Due Date',
                  value: _formatDate(invoice.dueDate),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Color _getStatusColor(String status) {
    switch (status.toLowerCase()) {
      case 'paid':
        return AppColors.success;
      case 'overdue':
        return AppColors.error;
      case 'pending':
        return AppColors.warning;
      default:
        return AppColors.textLight;
    }
  }

  String _formatDate(DateTime date) {
    return '${date.day}/${date.month}/${date.year}';
  }
}

class _InfoItem extends StatelessWidget {
  final String label;
  final String value;

  const _InfoItem({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

class _InvoiceItemsCard extends StatelessWidget {
  final InvoiceData invoice;

  const _InvoiceItemsCard({required this.invoice});

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Invoice Breakdown',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            ...invoice.items.map((item) => Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Text(
                          item.name,
                          style: const TextStyle(fontSize: 14),
                        ),
                      ),
                      Text(
                        '₹${item.amount.toStringAsFixed(2)}',
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                )),
          ],
        ),
      ),
    );
  }
}

class _PaymentSummaryCard extends StatelessWidget {
  final InvoiceData invoice;

  const _PaymentSummaryCard({required this.invoice});

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Payment Summary',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            _SummaryRow(label: 'Subtotal', amount: invoice.totalAmount),
            if (invoice.previousDues > 0)
              _SummaryRow(label: 'Previous Dues', amount: invoice.previousDues),
            if (invoice.lateFee > 0)
              _SummaryRow(label: 'Late Fee', amount: invoice.lateFee),
            const Divider(height: 24),
            _SummaryRow(
              label: 'Total Payable',
              amount: invoice.totalPayable,
              isTotal: true,
            ),
            if (invoice.paidAmount > 0) ...[
              const SizedBox(height: 12),
              _SummaryRow(label: 'Paid', amount: invoice.paidAmount),
              _SummaryRow(
                label: 'Outstanding',
                amount: invoice.outstandingAmount,
                isOutstanding: true,
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _SummaryRow extends StatelessWidget {
  final String label;
  final double amount;
  final bool isTotal;
  final bool isOutstanding;

  const _SummaryRow({
    required this.label,
    required this.amount,
    this.isTotal = false,
    this.isOutstanding = false,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: isTotal ? 16 : 14,
              fontWeight: isTotal ? FontWeight.bold : FontWeight.normal,
            ),
          ),
          Text(
            '₹${amount.toStringAsFixed(2)}',
            style: TextStyle(
              fontSize: isTotal ? 18 : 14,
              fontWeight: FontWeight.bold,
              color: isOutstanding
                  ? AppColors.error
                  : isTotal
                      ? AppColors.primary
                      : AppColors.textPrimary,
            ),
          ),
        ],
      ),
    );
  }
}

class _UpiInfoCard extends StatelessWidget {
  final UpiConfigData upiConfig;

  const _UpiInfoCard({required this.upiConfig});

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.account_balance_wallet, color: AppColors.primary),
                const SizedBox(width: 8),
                const Text(
                  'UPI Payment Details',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            _UpiInfoRow(label: 'UPI ID', value: upiConfig.upiId),
            _UpiInfoRow(label: 'Account Holder', value: upiConfig.accountHolderName),
            if (upiConfig.bankName != null)
              _UpiInfoRow(label: 'Bank', value: upiConfig.bankName!),
            if (upiConfig.qrCodeImage != null) ...[
              const SizedBox(height: 16),
              Center(
                child: Image.network(
                  upiConfig.qrCodeImage!.url,
                  width: 200,
                  height: 200,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _UpiInfoRow extends StatelessWidget {
  final String label;
  final String value;

  const _UpiInfoRow({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 100,
            child: Text(
              label,
              style: TextStyle(
                fontSize: 14,
                color: AppColors.textSecondary,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

