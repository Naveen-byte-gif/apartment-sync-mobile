import 'package:flutter/material.dart';
import '../../../core/imports/app_imports.dart';
import '../../../data/models/invoice_data.dart';
import 'invoice_detail_screen.dart';

class PaymentConfirmationScreen extends StatefulWidget {
  final String paymentId;
  final InvoiceData? invoice; // Optional - invoice may be generated after payment
  final double amount;
  final String? upiReferenceId;

  const PaymentConfirmationScreen({
    super.key,
    required this.paymentId,
    this.invoice, // Made optional
    required this.amount,
    this.upiReferenceId,
  });

  @override
  State<PaymentConfirmationScreen> createState() => _PaymentConfirmationScreenState();
}

class _PaymentConfirmationScreenState extends State<PaymentConfirmationScreen> {
  final _formKey = GlobalKey<FormState>();
  final _upiReferenceIdController = TextEditingController();
  DateTime _paymentDate = DateTime.now();
  bool _isSubmitting = false;

  @override
  void initState() {
    super.initState();
    if (widget.upiReferenceId != null) {
      _upiReferenceIdController.text = widget.upiReferenceId!;
    }
  }

  @override
  void dispose() {
    _upiReferenceIdController.dispose();
    super.dispose();
  }

  Future<void> _confirmPayment() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSubmitting = true);

    try {
      final response = await ApiService.post(
        ApiConstants.confirmPayment(widget.paymentId),
        {
          'upiReferenceId': _upiReferenceIdController.text.trim().isEmpty
              ? null
              : _upiReferenceIdController.text.trim(),
          'paymentDate': _paymentDate.toIso8601String(),
        },
      );

      if (response['success'] == true) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Payment confirmed successfully!'),
              backgroundColor: AppColors.success,
            ),
          );
          // Navigate based on whether invoice exists
          if (widget.invoice != null) {
            Navigator.pushAndRemoveUntil(
              context,
              MaterialPageRoute(
                builder: (_) => InvoiceDetailScreen(invoiceId: widget.invoice!.id),
              ),
              (route) => route.isFirst,
            );
          } else {
            // Navigate back to home or payment list if invoice was generated
            Navigator.popUntil(context, (route) => route.isFirst);
          }
        }
      } else {
        AppMessageHandler.handleError(
          context,
          response['message'] ?? 'Failed to confirm payment',
        );
      }
    } catch (e) {
      AppMessageHandler.handleError(context, e);
    } finally {
      if (mounted) {
        setState(() => _isSubmitting = false);
      }
    }
  }

  Future<void> _selectDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _paymentDate,
      firstDate: DateTime.now().subtract(const Duration(days: 30)),
      lastDate: DateTime.now(),
    );
    if (picked != null) {
      setState(() => _paymentDate = picked);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Confirm Payment'),
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Success icon
              Center(
                child: Container(
                  width: 80,
                  height: 80,
                  decoration: BoxDecoration(
                    color: AppColors.success.withOpacity(0.1),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.check_circle,
                    size: 50,
                    color: AppColors.success,
                  ),
                ),
              ),
              const SizedBox(height: 24),
              // Payment summary
              Card(
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
                      if (widget.invoice != null)
                        _SummaryRow(label: 'Invoice Number', value: widget.invoice!.invoiceNumber)
                      else
                        const _SummaryRow(
                          label: 'Invoice Number',
                          value: 'Will be generated after confirmation',
                        ),
                      _SummaryRow(
                        label: 'Amount',
                        value: '₹${widget.amount.toStringAsFixed(2)}',
                        isAmount: true,
                      ),
                      _SummaryRow(
                        label: 'Payment Date',
                        value: '${_paymentDate.day}/${_paymentDate.month}/${_paymentDate.year}',
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 24),
              // Instructions
              Card(
                color: AppColors.info.withOpacity(0.1),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(Icons.info_outline, color: AppColors.info),
                          const SizedBox(width: 8),
                          const Text(
                            'Payment Instructions',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Text(
                        widget.invoice != null
                          ? '1. Complete the payment in your UPI app\n'
                            '2. Copy the UPI Transaction Reference ID from the payment confirmation\n'
                            '3. Enter it below and confirm'
                          : '1. Complete the payment in your UPI app\n'
                            '2. Copy the UPI Transaction Reference ID from the payment confirmation\n'
                            '3. Enter it below and confirm\n\n'
                            'Note: Invoice will be automatically generated after you confirm the payment.',
                        style: const TextStyle(fontSize: 14),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 24),
              // UPI Reference ID
              TextFormField(
                controller: _upiReferenceIdController,
                decoration: InputDecoration(
                  labelText: 'UPI Transaction Reference ID',
                  hintText: 'Enter UPI reference ID (optional but recommended)',
                  prefixIcon: const Icon(Icons.receipt),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  helperText: 'This helps in faster verification',
                ),
              ),
              const SizedBox(height: 16),
              // Payment date
              InkWell(
                onTap: _selectDate,
                child: InputDecorator(
                  decoration: InputDecoration(
                    labelText: 'Payment Date',
                    prefixIcon: const Icon(Icons.calendar_today),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: Text(
                    '${_paymentDate.day}/${_paymentDate.month}/${_paymentDate.year}',
                    style: const TextStyle(fontSize: 16),
                  ),
                ),
              ),
              const SizedBox(height: 32),
              // Submit button
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _isSubmitting ? null : _confirmPayment,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: _isSubmitting
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                          ),
                        )
                      : const Text(
                          'Confirm Payment',
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

class _SummaryRow extends StatelessWidget {
  final String label;
  final String value;
  final bool isAmount;

  const _SummaryRow({
    required this.label,
    required this.value,
    this.isAmount = false,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 14,
              color: AppColors.textSecondary,
            ),
          ),
          Text(
            value,
            style: TextStyle(
              fontSize: isAmount ? 18 : 14,
              fontWeight: FontWeight.bold,
              color: isAmount ? AppColors.primary : AppColors.textPrimary,
            ),
          ),
        ],
      ),
    );
  }
}

