import '../../../../core/imports/app_imports.dart';
import '../../payments/invoice_list_screen.dart';

class PaymentsTabScreen extends StatelessWidget {
  const PaymentsTabScreen({super.key});

  @override
  Widget build(BuildContext context) {
    // Use the InvoiceListScreen which has all the payment functionality
    return const InvoiceListScreen();
  }
}

