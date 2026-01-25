import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../../core/imports/app_imports.dart';
import '../../../data/models/user_data.dart';
import 'dart:convert';

class CreateInvoiceScreen extends StatefulWidget {
  const CreateInvoiceScreen({super.key});

  @override
  State<CreateInvoiceScreen> createState() => _CreateInvoiceScreenState();
}

class _CreateInvoiceScreenState extends State<CreateInvoiceScreen> {
  final _formKey = GlobalKey<FormState>();
  final _notesController = TextEditingController();
  
  String? _selectedFlatId;
  List<Map<String, dynamic>> _residents = [];
  DateTime? _billingStartDate;
  DateTime? _billingEndDate;
  DateTime? _dueDate;
  List<InvoiceItem> _items = [];
  bool _isLoading = false;
  bool _isLoadingResidents = true;

  @override
  void initState() {
    super.initState();
    _loadResidents();
  }

  @override
  void dispose() {
    _notesController.dispose();
    super.dispose();
  }

  Future<void> _loadResidents() async {
    setState(() => _isLoadingResidents = true);
    try {
      final response = await ApiService.get(ApiConstants.adminResidents);
      if (response['success'] == true) {
        setState(() {
          _residents = List<Map<String, dynamic>>.from(
            response['data']?['residents'] ?? [],
          );
          _isLoadingResidents = false;
        });
      } else {
        AppMessageHandler.handleError(context, 'Failed to load residents');
        setState(() => _isLoadingResidents = false);
      }
    } catch (e) {
      AppMessageHandler.handleError(context, e);
      setState(() => _isLoadingResidents = false);
    }
  }

  Future<void> _selectDate(
    BuildContext context,
    Function(DateTime) onDateSelected,
    DateTime? initialDate,
  ) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: initialDate ?? DateTime.now(),
      firstDate: DateTime(2020),
      lastDate: DateTime(2030),
    );
    if (picked != null) {
      onDateSelected(picked);
    }
  }

  void _addItem() {
    setState(() {
      _items.add(InvoiceItem(name: '', amount: 0));
    });
  }

  void _removeItem(int index) {
    setState(() {
      _items.removeAt(index);
    });
  }

  void _updateItem(int index, String name, double amount) {
    setState(() {
      _items[index] = InvoiceItem(name: name, amount: amount);
    });
  }

  double get _totalAmount {
    return _items.fold(0.0, (sum, item) => sum + item.amount);
  }

  Future<void> _createInvoice() async {
    if (!_formKey.currentState!.validate()) return;

    if (_selectedFlatId == null) {
      AppMessageHandler.handleError(context, 'Please select a resident/flat');
      return;
    }

    if (_billingStartDate == null || _billingEndDate == null || _dueDate == null) {
      AppMessageHandler.handleError(context, 'Please select all dates');
      return;
    }

    if (_items.isEmpty) {
      AppMessageHandler.handleError(context, 'Please add at least one invoice item');
      return;
    }

    setState(() => _isLoading = true);

    try {
      final response = await ApiService.post(
        ApiConstants.invoices,
        {
          'flatId': _selectedFlatId,
          'billingPeriod': {
            'startDate': _billingStartDate!.toIso8601String(),
            'endDate': _billingEndDate!.toIso8601String(),
          },
          'items': _items.map((item) => {
            'name': item.name,
            'amount': item.amount,
          }).toList(),
          'dueDate': _dueDate!.toIso8601String(),
          'notes': _notesController.text.trim().isEmpty
              ? null
              : _notesController.text.trim(),
        },
      );

      if (response['success'] == true) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Invoice created successfully!'),
              backgroundColor: AppColors.success,
            ),
          );
          Navigator.pop(context);
        }
      } else {
        AppMessageHandler.handleError(
          context,
          response['message'] ?? 'Failed to create invoice',
        );
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
        title: const Text('Create Invoice'),
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
      ),
      body: _isLoadingResidents
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Select Resident/Flat
                    DropdownButtonFormField<String>(
                      value: _selectedFlatId,
                      decoration: InputDecoration(
                        labelText: 'Select Resident/Flat *',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        prefixIcon: const Icon(Icons.person),
                      ),
                      items: _residents.map((resident) {
                        final flatInfo = '${resident['building'] ?? ''} - ${resident['flatNumber'] ?? ''}';
                        final residentId = (resident['_id'] ?? resident['id'] ?? '').toString();
                        return DropdownMenuItem<String>(
                          value: residentId,
                          child: Text('${resident['fullName'] ?? 'Resident'} ($flatInfo)'),
                        );
                      }).toList(),
                      onChanged: (value) {
                        setState(() => _selectedFlatId = value);
                      },
                      validator: (value) {
                        if (value == null) {
                          return 'Please select a resident';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 24),
                    // Billing Period
                    const Text(
                      'Billing Period *',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: InkWell(
                            onTap: () => _selectDate(
                              context,
                              (date) => setState(() => _billingStartDate = date),
                              _billingStartDate,
                            ),
                            child: InputDecorator(
                              decoration: InputDecoration(
                                labelText: 'Start Date',
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                prefixIcon: const Icon(Icons.calendar_today),
                              ),
                              child: Text(
                                _billingStartDate != null
                                    ? DateFormat('dd MMM yyyy').format(_billingStartDate!)
                                    : 'Select start date',
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: InkWell(
                            onTap: () => _selectDate(
                              context,
                              (date) => setState(() => _billingEndDate = date),
                              _billingEndDate,
                            ),
                            child: InputDecorator(
                              decoration: InputDecoration(
                                labelText: 'End Date',
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                prefixIcon: const Icon(Icons.calendar_today),
                              ),
                              child: Text(
                                _billingEndDate != null
                                    ? DateFormat('dd MMM yyyy').format(_billingEndDate!)
                                    : 'Select end date',
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    // Due Date
                    InkWell(
                      onTap: () => _selectDate(
                        context,
                        (date) => setState(() => _dueDate = date),
                        _dueDate,
                      ),
                      child: InputDecorator(
                        decoration: InputDecoration(
                          labelText: 'Due Date *',
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          prefixIcon: const Icon(Icons.event),
                        ),
                        child: Text(
                          _dueDate != null
                              ? DateFormat('dd MMM yyyy').format(_dueDate!)
                              : 'Select due date',
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),
                    // Invoice Items
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'Invoice Items *',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        TextButton.icon(
                          onPressed: _addItem,
                          icon: const Icon(Icons.add),
                          label: const Text('Add Item'),
                        ),
                      ],
                    ),
                    ..._items.asMap().entries.map((entry) {
                      final index = entry.key;
                      final item = entry.value;
                      return _InvoiceItemWidget(
                        index: index,
                        item: item,
                        onUpdate: (name, amount) => _updateItem(index, name, amount),
                        onRemove: () => _removeItem(index),
                      );
                    }),
                    if (_items.isEmpty)
                      Container(
                        padding: const EdgeInsets.all(24),
                        decoration: BoxDecoration(
                          color: AppColors.background,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: AppColors.border),
                        ),
                        child: Center(
                          child: Column(
                            children: [
                              Icon(Icons.receipt_long, size: 48, color: AppColors.textLight),
                              const SizedBox(height: 12),
                              Text(
                                'No items added',
                                style: TextStyle(color: AppColors.textSecondary),
                              ),
                              const SizedBox(height: 8),
                              TextButton.icon(
                                onPressed: _addItem,
                                icon: const Icon(Icons.add),
                                label: const Text('Add First Item'),
                              ),
                            ],
                          ),
                        ),
                      ),
                    if (_items.isNotEmpty) ...[
                      const SizedBox(height: 16),
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: AppColors.primary.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text(
                              'Total Amount',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            Text(
                              '₹${_totalAmount.toStringAsFixed(2)}',
                              style: const TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                                color: AppColors.primary,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                    const SizedBox(height: 24),
                    // Notes
                    TextFormField(
                      controller: _notesController,
                      decoration: InputDecoration(
                        labelText: 'Notes (Optional)',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        prefixIcon: const Icon(Icons.note),
                      ),
                      maxLines: 3,
                    ),
                    const SizedBox(height: 32),
                    // Create button
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: _isLoading ? null : _createInvoice,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primary,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: _isLoading
                            ? const SizedBox(
                                height: 20,
                                width: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                                ),
                              )
                            : const Text(
                                'Create Invoice',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                ),
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

class InvoiceItem {
  String name;
  double amount;

  InvoiceItem({required this.name, required this.amount});
}

class _InvoiceItemWidget extends StatelessWidget {
  final int index;
  final InvoiceItem item;
  final Function(String, double) onUpdate;
  final VoidCallback onRemove;

  const _InvoiceItemWidget({
    required this.index,
    required this.item,
    required this.onUpdate,
    required this.onRemove,
  });

  @override
  Widget build(BuildContext context) {
    final nameController = TextEditingController(text: item.name);
    final amountController = TextEditingController(
      text: item.amount > 0 ? item.amount.toStringAsFixed(2) : '',
    );

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    '${index + 1}',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: AppColors.primary,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextFormField(
                    controller: nameController,
                    decoration: const InputDecoration(
                      labelText: 'Item Name',
                      border: OutlineInputBorder(),
                    ),
                    onChanged: (value) {
                      final amount = double.tryParse(amountController.text) ?? 0;
                      onUpdate(value, amount);
                    },
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextFormField(
                    controller: amountController,
                    decoration: const InputDecoration(
                      labelText: 'Amount (₹)',
                      border: OutlineInputBorder(),
                      prefixText: '₹',
                    ),
                    keyboardType: TextInputType.numberWithOptions(decimal: true),
                    onChanged: (value) {
                      final amount = double.tryParse(value) ?? 0;
                      onUpdate(nameController.text, amount);
                    },
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.delete, color: AppColors.error),
                  onPressed: onRemove,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

