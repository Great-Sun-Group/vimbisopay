import 'package:flutter/material.dart';
import 'package:vimbisopay_app/core/theme/app_colors.dart';
import 'package:vimbisopay_app/core/utils/logger.dart';
import 'package:vimbisopay_app/domain/repositories/marketplace/marketplace_repository.dart';
import 'package:vimbisopay_app/infrastructure/services/service_locator.dart';
import 'package:vimbisopay_app/presentation/models/sales_basket.dart';
import 'package:qr_flutter/qr_flutter.dart';

/// A screen for generating invoices from a sales basket.
///
/// This screen allows vendors to review the items in their basket
/// and generate an invoice for the customer.
class InvoiceGenerationScreen extends StatefulWidget {
  /// The sales basket containing the items to be invoiced.
  final SalesBasket basket;

  /// Creates a new [InvoiceGenerationScreen] instance.
  const InvoiceGenerationScreen({
    super.key,
    required this.basket,
  });

  @override
  State<InvoiceGenerationScreen> createState() =>
      _InvoiceGenerationScreenState();
}

class _InvoiceGenerationScreenState extends State<InvoiceGenerationScreen> {
  final MarketplaceRepository _marketplaceRepository =
      ServiceLocator.marketplaceRepository;

  final _formKey = GlobalKey<FormState>();
  final _notesController = TextEditingController();

  bool _isLoading = false;
  String? _errorMessage;
  String? _invoiceId;
  String? _invoiceQrData;

  @override
  void dispose() {
    _notesController.dispose();
    super.dispose();
  }

  Future<void> _generateInvoice() async {
    Logger.data('[INVOICE_GENERATION] Starting invoice generation process');
    
    // Generate a correlation ID for tracking this specific invoice generation flow
    final correlationId = 'inv_${DateTime.now().millisecondsSinceEpoch}';
    Logger.data('[INVOICE_GENERATION] [$correlationId] Correlation ID assigned');
    
    // Log form validation
    if (!_formKey.currentState!.validate()) {
      Logger.data('[INVOICE_GENERATION] [$correlationId] Form validation failed, aborting invoice generation');
      return;
    }
    Logger.data('[INVOICE_GENERATION] [$correlationId] Form validation successful');

    // Log UI state change
    Logger.data('[INVOICE_GENERATION] [$correlationId] Setting UI to loading state');
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      // Log basket details
      Logger.data('[INVOICE_GENERATION] [$correlationId] Basket details: ${widget.basket.items.length} items, total price: ${widget.basket.totalPrice}');
      
      // Get line items from the basket
      final lineItems = widget.basket.toInvoiceLineItems();
      
      // Log line items details
      for (var i = 0; i < lineItems.length; i++) {
        final item = lineItems[i];
        Logger.data('[INVOICE_GENERATION] [$correlationId] Line item #${i + 1}: productId=${item.productId}, name=${item.productName}, quantity=${item.quantity}, unitPrice=${item.unitPrice}, totalPrice=${item.totalPrice}');
      }

      // Log user authentication attempt
      Logger.data('[INVOICE_GENERATION] [$correlationId] Retrieving authenticated user');
      final user = await ServiceLocator.databaseHelper.getUser();
      if (user == null) {
        Logger.error('[INVOICE_GENERATION] [$correlationId] User authentication failed: user not found in database');
        setState(() {
          _isLoading = false;
          _errorMessage = 'User not authenticated';
        });
        return;
      }
      
      // Log basket validation
      if (widget.basket.items.isEmpty) {
        Logger.error('[INVOICE_GENERATION] [$correlationId] Validation failed: Basket is empty');
        setState(() {
          _isLoading = false;
          _errorMessage = 'Basket is empty';
        });
        return;
      }
      
      // Log currency validation
      final currency = widget.basket.items.first.product.currency;
      Logger.data('[INVOICE_GENERATION] [$correlationId] Starting currency validation, base currency: $currency');
      
      for (var i = 0; i < widget.basket.items.length; i++) {
        final item = widget.basket.items[i];
        final itemCurrency = item.product.currency;
        Logger.data('[INVOICE_GENERATION] [$correlationId] Item #${i + 1} currency: $itemCurrency');
        
        if (itemCurrency != currency) {
          Logger.error('[INVOICE_GENERATION] [$correlationId] Currency validation failed: Item #${i + 1} has currency $itemCurrency, expected $currency');
          setState(() {
            _isLoading = false;
            _errorMessage = 'All items must have the same currency';
          });
          return;
        }
      }
      Logger.data('[INVOICE_GENERATION] [$correlationId] Currency validation successful: all items have currency $currency');

      // Log repository call parameters
      Logger.data('[INVOICE_GENERATION] [$correlationId] Preparing to call createInvoice with parameters:');
      Logger.data('[INVOICE_GENERATION] [$correlationId] - vendorId: ${widget.basket.vendor.id}');
      Logger.data('[INVOICE_GENERATION] [$correlationId] - lineItems: ${lineItems.length} items');
      Logger.data('[INVOICE_GENERATION] [$correlationId] - totalAmount: ${widget.basket.totalPrice}');
      Logger.data('[INVOICE_GENERATION] [$correlationId] - currency: $currency');
      Logger.data('[INVOICE_GENERATION] [$correlationId] - paymentMethod: credex');
      Logger.data('[INVOICE_GENERATION] [$correlationId] - notes: ${_notesController.text.isNotEmpty ? '${_notesController.text.length} characters' : 'null'}');
      
      // Start timing the API call
      final stopwatch = Stopwatch()..start();
      
      // Create invoice using repository
      Logger.data('[INVOICE_GENERATION] [$correlationId] Calling repository.createInvoice()');
      final result = await _marketplaceRepository.createInvoice(
        vendorId: widget.basket.vendor.id,
        lineItems: lineItems,
        totalAmount: widget.basket.totalPrice,
        currency: currency,
        paymentMethod: 'credex', // Default payment method
        notes: _notesController.text.isNotEmpty ? _notesController.text : null,
      );

      // Log API call duration
      stopwatch.stop();
      Logger.performance('[INVOICE_GENERATION] [$correlationId] Repository call completed in ${stopwatch.elapsedMilliseconds}ms');

      // Process result
      result.fold(
        (failure) {
          // Log failure details
          Logger.error('[INVOICE_GENERATION] [$correlationId] Failed to generate invoice', failure);
          Logger.error('[INVOICE_GENERATION] [$correlationId] Failure type: ${failure.runtimeType}');
          Logger.error('[INVOICE_GENERATION] [$correlationId] Failure message: ${failure.message}');
          
          // Update UI state
          Logger.data('[INVOICE_GENERATION] [$correlationId] Updating UI to show error');
          setState(() {
            _isLoading = false;
            _errorMessage = failure.message ?? 'Failed to generate invoice';
          });
        },
        (invoice) {
          // Log success details
          Logger.data('[INVOICE_GENERATION] [$correlationId] Invoice generated successfully');
          Logger.data('[INVOICE_GENERATION] [$correlationId] Invoice ID: ${invoice.id}');
          Logger.data('[INVOICE_GENERATION] [$correlationId] Invoice buyer ID: ${invoice.buyerId}');
          Logger.data('[INVOICE_GENERATION] [$correlationId] Invoice vendor ID: ${invoice.vendorId}');
          Logger.data('[INVOICE_GENERATION] [$correlationId] Invoice total amount: ${invoice.totalAmount}');
          Logger.data('[INVOICE_GENERATION] [$correlationId] Invoice currency: ${invoice.currency}');
          Logger.data('[INVOICE_GENERATION] [$correlationId] Invoice status: ${invoice.status}');
          Logger.data('[INVOICE_GENERATION] [$correlationId] Invoice created at: ${invoice.createdAt}');
          
          // Log QR code generation
          final hasQrLink = invoice.invoiceQrLink != null && invoice.invoiceQrLink!.isNotEmpty;
          Logger.data('[INVOICE_GENERATION] [$correlationId] Invoice QR link from API: ${hasQrLink ? 'available' : 'not available'}');
          
          // Use the QR link from the API response if available, otherwise fall back to a deep link format
          final qrData = invoice.invoiceQrLink ?? 'vimbisopay://invoice/${invoice.id}';
          Logger.data('[INVOICE_GENERATION] [$correlationId] Using QR data: $qrData');
          Logger.data('[INVOICE_GENERATION] [$correlationId] QR data source: ${hasQrLink ? 'API response' : 'local deep link fallback'}');
          
          // Update UI state
          Logger.data('[INVOICE_GENERATION] [$correlationId] Updating UI to show success');
          setState(() {
            _isLoading = false;
            _invoiceId = invoice.id;
            _invoiceQrData = qrData;
          });
          
          Logger.data('[INVOICE_GENERATION] [$correlationId] Invoice generation process completed successfully');
        },
      );
    } catch (e, stackTrace) {
      // Log detailed error information
      Logger.error('[INVOICE_GENERATION] [$correlationId] Unhandled exception during invoice generation', e, stackTrace);
      Logger.error('[INVOICE_GENERATION] [$correlationId] Exception type: ${e.runtimeType}');
      Logger.error('[INVOICE_GENERATION] [$correlationId] Exception message: $e');
      
      // Update UI state
      Logger.data('[INVOICE_GENERATION] [$correlationId] Updating UI to show error from exception');
      setState(() {
        _isLoading = false;
        _errorMessage = 'Failed to generate invoice: $e';
      });
      
      Logger.data('[INVOICE_GENERATION] [$correlationId] Invoice generation process failed');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Generate Invoice'),
      ),
      body: _invoiceId != null ? _buildInvoiceSuccess() : _buildInvoiceForm(),
      bottomNavigationBar: _invoiceId == null ? _buildBottomBar() : null,
    );
  }

  Widget _buildBottomBar() {
    return Container(
      padding: const EdgeInsets.all(16.0),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        boxShadow: [
          BoxShadow(
            color: AppColors.black.withOpacity(0.1),
            blurRadius: 4,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: SafeArea(
        child: FilledButton(
          onPressed: _isLoading ? null : _generateInvoice,
          child: _isLoading
              ? const SizedBox(
                  height: 20,
                  width: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    valueColor: AlwaysStoppedAnimation<Color>(AppColors.white),
                  ),
                )
              : const Text('Generate Invoice'),
        ),
      ),
    );
  }

  Widget _buildInvoiceForm() {
    return Form(
      key: _formKey,
      child: ListView(
        padding: const EdgeInsets.all(16.0),
        children: [
          if (_errorMessage != null) ...[
            Container(
              padding: const EdgeInsets.all(8.0),
              decoration: BoxDecoration(
                color: AppColors.errorRed.withOpacity(0.1),
                borderRadius: BorderRadius.circular(4.0),
                border: Border.all(color: AppColors.errorRed),
              ),
              child: Text(
                _errorMessage!,
                style: const TextStyle(color: AppColors.errorRed),
              ),
            ),
            const SizedBox(height: 16.0),
          ],
          _buildBasketSummary(),
          const SizedBox(height: 24.0),
          _buildNotesSection(),
          const SizedBox(height: 32.0),
        ],
      ),
    );
  }

  Widget _buildBasketSummary() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Basket Summary',
              style: TextStyle(
                fontSize: 18.0,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16.0),
            ListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: widget.basket.items.length,
              itemBuilder: (context, index) {
                final item = widget.basket.items[index];
                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4.0),
                  child: ListTile(
                    contentPadding: const EdgeInsets.symmetric(horizontal: 8.0),
                    title: Text(
                      item.product.name,
                      style: const TextStyle(
                        fontWeight: FontWeight.w500,
                        fontSize: 16.0,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    trailing: Text(
                      item.formattedTotalPrice,
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        color: AppColors.primary,
                        fontSize: 16.0,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                );
              },
            ),
            const Divider(),
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 8.0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Total',
                    style: TextStyle(
                      fontSize: 18.0,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Text(
                    widget.basket.formattedTotalPrice,
                    style: const TextStyle(
                      fontSize: 18.0,
                      fontWeight: FontWeight.bold,
                      color: AppColors.primary,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNotesSection() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Notes (Optional)',
              style: TextStyle(
                fontSize: 18.0,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16.0),
            TextFormField(
              controller: _notesController,
              decoration: const InputDecoration(
                labelText: 'Notes',
                hintText: 'Enter any additional notes for this invoice',
                border: OutlineInputBorder(),
                alignLabelWithHint: true,
              ),
              maxLines: 3,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInvoiceSuccess() {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              Icons.check_circle,
              color: AppColors.successGreen,
              size: 64,
            ),
            const SizedBox(height: 16),
            const Text(
              'Invoice Generated Successfully',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              'Invoice ID: $_invoiceId',
              style: const TextStyle(
                fontSize: 16,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 32),
            const Text(
              'Have the buyer scan this QR code to view and pay the invoice',
              style: TextStyle(
                fontSize: 16,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.white,
                borderRadius: BorderRadius.circular(8),
                boxShadow: [
                  BoxShadow(
                    color: AppColors.black.withOpacity(0.1),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: QrImageView(
                data: _invoiceQrData!,
                version: QrVersions.auto,
                size: 200,
                backgroundColor: AppColors.white,
                errorStateBuilder: (context, error) {
                  return const Center(
                    child: Text(
                      'Error generating QR code',
                      style: TextStyle(color: AppColors.errorRed),
                    ),
                  );
                },
              ),
            ),
            const SizedBox(height: 32),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                OutlinedButton.icon(
                  icon: const Icon(Icons.share),
                  label: const Text('Share'),
                  onPressed: () {
                    // TODO: Implement share functionality
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Share functionality coming soon'),
                      ),
                    );
                  },
                ),
                const SizedBox(width: 16),
                FilledButton.icon(
                  icon: const Icon(Icons.done),
                  label: const Text('Done'),
                  onPressed: () {
                    Navigator.pop(context, true);
                  },
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
