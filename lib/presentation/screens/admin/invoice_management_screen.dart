import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../../core/imports/app_imports.dart';
import '../../../data/models/invoice_data.dart';
import '../payments/invoice_detail_screen.dart';
import 'create_invoice_screen.dart';

class InvoiceManagementScreen extends StatefulWidget {
  const InvoiceManagementScreen({super.key});

  @override
  State<InvoiceManagementScreen> createState() => _InvoiceManagementScreenState();
}

class _InvoiceManagementScreenState extends State<InvoiceManagementScreen> {
  List<InvoiceData> _invoices = [];
  bool _isLoading = true;
  String? _selectedStatus;
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _loadInvoices();
  }

  Future<void> _loadInvoices() async {
    setState(() => _isLoading = true);
    try {
      String endpoint = ApiConstants.invoices;
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

  List<InvoiceData> get _filteredInvoices {
    if (_searchQuery.isEmpty) return _invoices;
    final query = _searchQuery.toLowerCase();
    return _invoices.where((invoice) {
      return invoice.invoiceNumber.toLowerCase().contains(query) ||
          invoice.flatNumber.toLowerCase().contains(query) ||
          invoice.building.toLowerCase().contains(query);
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Invoice Management'),
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.add),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const CreateInvoiceScreen()),
              ).then((_) => _loadInvoices());
            },
            tooltip: 'Create Invoice',
          ),
        ],
      ),
      body: Column(
        children: [
          // Search bar
          Padding(
            padding: const EdgeInsets.all(16),
            child: TextField(
              decoration: InputDecoration(
                hintText: 'Search by invoice number, flat, building...',
                prefixIcon: const Icon(Icons.search),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                filled: true,
                fillColor: AppColors.surface,
              ),
              onChanged: (value) {
                setState(() => _searchQuery = value);
              },
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
                : _filteredInvoices.isEmpty
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
                            const SizedBox(height: 8),
                            ElevatedButton.icon(
                              onPressed: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(builder: (_) => const CreateInvoiceScreen()),
                                ).then((_) => _loadInvoices());
                              },
                              icon: const Icon(Icons.add),
                              label: const Text('Create First Invoice'),
                            ),
                          ],
                        ),
                      )
                    : RefreshIndicator(
                        onRefresh: _loadInvoices,
                        child: ListView.builder(
                          padding: const EdgeInsets.all(16),
                          itemCount: _filteredInvoices.length,
                          itemBuilder: (context, index) {
                            return _InvoiceCard(
                              invoice: _filteredInvoices[index],
                              onTap: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) => InvoiceDetailScreen(
                                      invoiceId: _filteredInvoices[index].id,
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
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const CreateInvoiceScreen()),
          ).then((_) => _loadInvoices());
        },
        icon: const Icon(Icons.add),
        label: const Text('Create Invoice'),
        backgroundColor: AppColors.primary,
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

class _InvoiceCard extends StatelessWidget {
  final InvoiceData invoice;
  final VoidCallback onTap;

  const _InvoiceCard({
    required this.invoice,
    required this.onTap,
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
                          '${invoice.building} - ${invoice.flatNumber}',
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
              const SizedBox(height: 8),
              Text(
                'Due: ${DateFormat('dd MMM yyyy').format(invoice.dueDate)}',
                style: TextStyle(
                  fontSize: 12,
                  color: AppColors.textSecondary,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

