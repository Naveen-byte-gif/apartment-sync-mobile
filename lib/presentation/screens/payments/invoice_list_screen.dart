import 'package:flutter/material.dart';
import '../../../core/imports/app_imports.dart';
import '../../../data/models/invoice_data.dart';
import 'invoice_detail_screen.dart';
import 'payment_entry_screen.dart';

class InvoiceListScreen extends StatefulWidget {
  final bool showAppBar;

  const InvoiceListScreen({super.key, this.showAppBar = true});

  @override
  State<InvoiceListScreen> createState() => _InvoiceListScreenState();
}

class _InvoiceListScreenState extends State<InvoiceListScreen> {
  List<InvoiceData> _invoices = [];
  bool _isLoading = true;
  String? _selectedStatus;

  @override
  void initState() {
    super.initState();
    _loadInvoices();
  }

  double get _totalOutstanding {
    return _invoices
        .where((inv) => inv.status != 'paid')
        .fold(0.0, (sum, inv) => sum + inv.outstandingAmount);
  }

  InvoiceData? get _nextDueInvoice {
    final pendingInvoices = _invoices
        .where((inv) => inv.status != 'paid' && inv.outstandingAmount > 0)
        .toList();
    if (pendingInvoices.isEmpty) return null;
    pendingInvoices.sort((a, b) => a.dueDate.compareTo(b.dueDate));
    return pendingInvoices.first;
  }

  Future<void> _loadInvoices() async {
    setState(() => _isLoading = true);
    try {
      String endpoint = ApiConstants.myInvoices;
      if (_selectedStatus != null) {
        endpoint += '?status=$_selectedStatus';
      }

      final response = await ApiService.get(endpoint);
      if (response['success'] == true) {
        final invoicesData = response['data']?['invoices'] ?? [];
        setState(() {
          _invoices = (invoicesData as List)
              .map((item) => InvoiceData.fromJson(item))
              .toList();
          _isLoading = false;
        });
      } else {
        AppMessageHandler.handleError(context, response['message'] ?? 'Failed to load invoices');
        setState(() => _isLoading = false);
      }
    } catch (e) {
      AppMessageHandler.handleError(context, e);
      setState(() => _isLoading = false);
    }
  }

  String _formatDate(DateTime date) {
    return '${date.day}/${date.month}/${date.year}';
  }

  @override
  Widget build(BuildContext context) {
    final body = Column(
        children: [
          // Total Outstanding Summary Card (only show if there are outstanding invoices)
          if (_totalOutstanding > 0 && !_isLoading)
            Container(
              margin: const EdgeInsets.all(16),
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    AppColors.primary,
                    AppColors.primaryDark,
                  ],
                ),
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: AppColors.primary.withOpacity(0.3),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
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
                            const Text(
                              'Total Outstanding',
                              style: TextStyle(
                                color: Colors.white70,
                                fontSize: 14,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              '₹${_totalOutstanding.toStringAsFixed(2)}',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 32,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            if (_nextDueInvoice != null) ...[
                              const SizedBox(height: 8),
                              Row(
                                children: [
                                  const Icon(
                                    Icons.calendar_today,
                                    color: Colors.white70,
                                    size: 16,
                                  ),
                                  const SizedBox(width: 4),
                                  Text(
                                    'Next due: ${_formatDate(_nextDueInvoice!.dueDate)}',
                                    style: const TextStyle(
                                      color: Colors.white70,
                                      fontSize: 12,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ],
                        ),
                      ),
                      if (_nextDueInvoice != null)
                        ElevatedButton(
                          onPressed: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => InvoiceDetailScreen(
                                  invoiceId: _nextDueInvoice!.id,
                                ),
                              ),
                            ).then((_) => _loadInvoices());
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.white,
                            foregroundColor: AppColors.primary,
                            padding: const EdgeInsets.symmetric(
                              horizontal: 20,
                              vertical: 12,
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          child: const Text(
                            'Pay Now',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                    ],
                  ),
                ],
              ),
            ),
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
                      _loadInvoices();
                    },
                  ),
                  const SizedBox(width: 8),
                  _FilterChip(
                    label: 'Pending',
                    isSelected: _selectedStatus == 'pending',
                    onTap: () {
                      setState(() => _selectedStatus = 'pending');
                      _loadInvoices();
                    },
                  ),
                  const SizedBox(width: 8),
                  _FilterChip(
                    label: 'Overdue',
                    isSelected: _selectedStatus == 'overdue',
                    onTap: () {
                      setState(() => _selectedStatus = 'overdue');
                      _loadInvoices();
                    },
                  ),
                  const SizedBox(width: 8),
                  _FilterChip(
                    label: 'Paid',
                    isSelected: _selectedStatus == 'paid',
                    onTap: () {
                      setState(() => _selectedStatus = 'paid');
                      _loadInvoices();
                    },
                  ),
                ],
              ),
            ),
          ),
          // Invoice list
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _invoices.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.receipt_long, size: 64, color: AppColors.textLight),
                            const SizedBox(height: 16),
                            Text(
                              'No invoices found',
                              style: TextStyle(color: AppColors.textSecondary),
                            ),
                          ],
                        ),
                      )
                    : RefreshIndicator(
                        onRefresh: _loadInvoices,
                        child: ListView.builder(
                          padding: const EdgeInsets.all(16),
                          itemCount: _invoices.length,
                          itemBuilder: (context, index) {
                            return _InvoiceCard(
                              invoice: _invoices[index],
                              onTap: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) => InvoiceDetailScreen(
                                      invoiceId: _invoices[index].id,
                                    ),
                                  ),
                                ).then((_) => _loadInvoices());
                              },
                              onPayNow: () {
                                // Direct payment - go to payment entry screen
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) => PaymentEntryScreen(
                                      invoice: _invoices[index],
                                    ),
                                  ),
                                ).then((_) => _loadInvoices());
                              },
                            );
                          },
                        ),
                      ),
          ),
        ],
      );

    if (widget.showAppBar) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('My Invoices'),
          backgroundColor: AppColors.primary,
          foregroundColor: Colors.white,
        ),
        body: body,
      );
    }

    return body;
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

class _InvoiceCard extends StatelessWidget {
  final InvoiceData invoice;
  final VoidCallback onTap;
  final VoidCallback? onPayNow;

  const _InvoiceCard({
    required this.invoice,
    required this.onTap,
    this.onPayNow,
  });

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

  @override
  Widget build(BuildContext context) {
    final isOverdue = invoice.status == 'overdue' && DateTime.now().isAfter(invoice.dueDate);
    
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
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
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Due: ${_formatDate(invoice.dueDate)}',
                          style: TextStyle(
                            fontSize: 12,
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
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        color: _getStatusColor(invoice.status),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Total Payable',
                        style: TextStyle(
                          fontSize: 12,
                          color: AppColors.textSecondary,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '₹${invoice.totalPayable.toStringAsFixed(2)}',
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: AppColors.primary,
                        ),
                      ),
                    ],
                  ),
                  if (invoice.outstandingAmount > 0)
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          'Outstanding',
                          style: TextStyle(
                            fontSize: 12,
                            color: AppColors.textSecondary,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '₹${invoice.outstandingAmount.toStringAsFixed(2)}',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: isOverdue ? AppColors.error : AppColors.warning,
                          ),
                        ),
                      ],
                    ),
                ],
               ),
               // Pay Now Button - Show if invoice is not paid and has outstanding amount
               if (invoice.status != 'paid' && invoice.outstandingAmount > 0 && onPayNow != null) ...[
                 const SizedBox(height: 12),
                 SizedBox(
                   width: double.infinity,
                   child: ElevatedButton.icon(
                     onPressed: onPayNow,
                     icon: const Icon(Icons.payment, size: 20),
                     label: Text(
                       isOverdue ? 'Pay Now (Overdue)' : 'Pay Now',
                       style: const TextStyle(
                         fontSize: 14,
                         fontWeight: FontWeight.bold,
                       ),
                     ),
                     style: ElevatedButton.styleFrom(
                       backgroundColor: isOverdue ? AppColors.error : AppColors.primary,
                       foregroundColor: Colors.white,
                       padding: const EdgeInsets.symmetric(vertical: 12),
                       shape: RoundedRectangleBorder(
                         borderRadius: BorderRadius.circular(12),
                       ),
                       elevation: 2,
                     ),
                   ),
                 ),
               ],
             ],
           ),
         ),
       ),
     );
   }
 
   String _formatDate(DateTime date) {
     return '${date.day}/${date.month}/${date.year}';
   }
 }


