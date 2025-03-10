import 'package:flutter/material.dart';
import 'package:vimbisopay_app/core/theme/app_colors.dart';
import 'package:vimbisopay_app/core/utils/logger.dart';
import 'package:vimbisopay_app/domain/entities/marketplace/index.dart';
import 'package:vimbisopay_app/domain/repositories/marketplace/marketplace_repository.dart';
import 'package:vimbisopay_app/infrastructure/services/service_locator.dart';
import 'package:vimbisopay_app/presentation/models/basket_item.dart';
import 'package:vimbisopay_app/presentation/models/sales_basket.dart';
import 'package:qr_flutter/qr_flutter.dart';

/// A screen for generating invoices from a sales basket.
///
/// This screen allows vendors to review the items in their basket,
/// add buyer information, and generate an invoice for the customer.
class InvoiceGenerationScreen extends StatefulWidget {
  /// The sales basket containing the items to be invoiced.
  final SalesBasket basket;

  /// Creates a new [InvoiceGenerationScreen] instance.
  const InvoiceGenerationScreen({
    super.key,
    required this.basket,
  });

  @override
  State<InvoiceGenerationScreen> createState() => _InvoiceGenerationScreenState();
}

class _InvoiceGenerationScreenState extends State<InvoiceGenerationScreen> {
  final MarketplaceRepository _marketplaceRepository = ServiceLocator.marketplaceRepository;
  
  final _formKey = GlobalKey<FormState>();
  final _buyerNameController = TextEditingController();
  final _buyerEmailController = TextEditingController();
  final _buyerPhoneController = TextEditingController();
  final _notesController = TextEditingController();
  
  bool _isLoading = false;
  String? _errorMessage;
  String? _invoiceId;
  String? _invoiceQrData;
  
  @override
  void dispose() {
    _buyerNameController.dispose();
    _buyerEmailController.dispose();
    _buyerPhoneController.dispose();
    _notesController.dispose();
    super.dispose();
  }
  
  Future<void> _generateInvoice() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }
    
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });
    
    try {
      // Get line items from the basket
      final lineItems = widget.basket.toInvoiceLineItems();
      
      // Get buyer ID (in a real app, this would be the logged-in user's ID)
      // For now, we'll use a mock buyer ID
      const buyerId = 'm3'; // Mock buyer ID
      
      // Create invoice using repository
      final result = await _marketplaceRepository.createInvoice(
        buyerId: buyerId,
        vendorId: widget.basket.vendor.id,
        lineItems: lineItems,
        totalAmount: widget.basket.totalPrice,
        currency: widget.basket.items.first.product.currency, // Assuming all items have the same currency
        paymentMethod: 'credex', // Default payment method
        notes: _notesController.text.isNotEmpty ? _notesController.text : null,
      );
      
      result.fold(
        (failure) {
          setState(() {
            _isLoading = false;
            _errorMessage = failure.message ?? 'Failed to generate invoice';
          });
        },
        (invoice) {
          // Generate QR code data
          final qrData = 'vimbisopay://invoice/${invoice.id}';
          
          // Update inventory for each product in the basket
          _updateInventory(widget.basket.items).then((_) {
            setState(() {
              _isLoading = false;
              _invoiceId = invoice.id;
              _invoiceQrData = qrData;
            });
            
            // Log success
            Logger.data('Invoice generated successfully: ${invoice.id}');
          });
        },
      );
    } catch (e) {
      setState(() {
        _isLoading = false;
        _errorMessage = 'Failed to generate invoice: $e';
      });
      Logger.error('Error generating invoice', e);
    }
  }
  
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Generate Invoice'),
      ),
      body: _invoiceId != null
          ? _buildInvoiceSuccess()
          : _buildInvoiceForm(),
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
                color: Colors.red.withOpacity(0.1),
                borderRadius: BorderRadius.circular(4.0),
                border: Border.all(color: Colors.red),
              ),
              child: Text(
                _errorMessage!,
                style: const TextStyle(color: Colors.red),
              ),
            ),
            const SizedBox(height: 16.0),
          ],
          _buildBasketSummary(),
          const SizedBox(height: 24.0),
          _buildBuyerInfoSection(),
          const SizedBox(height: 24.0),
          _buildNotesSection(),
          const SizedBox(height: 32.0),
          FilledButton(
            onPressed: _isLoading ? null : _generateInvoice,
            child: _isLoading
                ? const SizedBox(
                    height: 20,
                    width: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                    ),
                  )
                : const Text('Generate Invoice'),
          ),
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
                return ListTile(
                  title: Text(
                    item.product.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  subtitle: Text(
                    '${item.quantity} x ${item.product.formattedPrice}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  trailing: Text(
                    item.formattedTotalPrice,
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      color: AppColors.primary,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
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
  
  Widget _buildBuyerInfoSection() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Buyer Information (Optional)',
              style: TextStyle(
                fontSize: 18.0,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16.0),
            TextFormField(
              controller: _buyerNameController,
              decoration: const InputDecoration(
                labelText: 'Name',
                hintText: 'Enter buyer\'s name',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16.0),
            TextFormField(
              controller: _buyerEmailController,
              decoration: const InputDecoration(
                labelText: 'Email',
                hintText: 'Enter buyer\'s email',
                border: OutlineInputBorder(),
              ),
              keyboardType: TextInputType.emailAddress,
              validator: (value) {
                if (value != null && value.isNotEmpty) {
                  // Simple email validation
                  if (!value.contains('@') || !value.contains('.')) {
                    return 'Please enter a valid email';
                  }
                }
                return null;
              },
            ),
            const SizedBox(height: 16.0),
            TextFormField(
              controller: _buyerPhoneController,
              decoration: const InputDecoration(
                labelText: 'Phone',
                hintText: 'Enter buyer\'s phone number',
                border: OutlineInputBorder(),
              ),
              keyboardType: TextInputType.phone,
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
  
  /// Updates the inventory for each product in the basket.
  ///
  /// This method is called after an invoice is generated to reduce the inventory
  /// of each product by the quantity purchased.
  Future<void> _updateInventory(List<BasketItem> items) async {
    for (final item in items) {
      try {
        // Get the current product to get its current inventory
        final productResult = await _marketplaceRepository.getProduct(item.product.id);
        
        await productResult.fold(
          (failure) {
            Logger.error('Failed to get product for inventory update', failure);
          },
          (product) async {
            // Calculate new inventory
            final currentInventory = product.inventory ?? 0;
            final newInventory = currentInventory - item.quantity;
            
            // Update product inventory
            final updateResult = await _marketplaceRepository.updateProduct(
              id: product.id,
              inventory: (newInventory >= 0 ? newInventory : 0).toInt(), // Prevent negative inventory and convert to int
            );
            
            updateResult.fold(
              (failure) {
                Logger.error('Failed to update product inventory', failure);
              },
              (updatedProduct) {
                Logger.data('Updated inventory for ${product.name}: $currentInventory -> ${updatedProduct.inventory}');
              },
            );
          },
        );
      } catch (e) {
        Logger.error('Error updating inventory for product ${item.product.id}', e);
      }
    }
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
              color: Colors.green,
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
                color: Colors.white,
                borderRadius: BorderRadius.circular(8),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.1),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: QrImageView(
                data: _invoiceQrData!,
                version: QrVersions.auto,
                size: 200,
                backgroundColor: Colors.white,
                errorStateBuilder: (context, error) {
                  return const Center(
                    child: Text(
                      'Error generating QR code',
                      style: TextStyle(color: Colors.red),
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
