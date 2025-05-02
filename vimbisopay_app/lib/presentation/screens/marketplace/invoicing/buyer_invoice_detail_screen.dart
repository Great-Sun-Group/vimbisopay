import 'package:flutter/material.dart';
import 'package:vimbisopay_app/core/theme/app_colors.dart';
import 'package:vimbisopay_app/core/utils/logger.dart';
import 'package:vimbisopay_app/domain/entities/marketplace/index.dart';
import 'package:vimbisopay_app/domain/repositories/marketplace/marketplace_repository.dart';
import 'package:vimbisopay_app/infrastructure/services/service_locator.dart';
import 'package:vimbisopay_app/presentation/screens/marketplace/invoicing/payment_screen.dart';
import 'package:vimbisopay_app/presentation/widgets/loading_dialog.dart';

/// A screen that displays invoice details to a buyer.
///
/// This screen is shown after a buyer scans an invoice QR code.
/// It displays the invoice details and allows the buyer to pay the invoice.
class BuyerInvoiceDetailScreen extends StatefulWidget {
  /// The ID of the invoice to display.
  final String invoiceId;

  /// Creates a new [BuyerInvoiceDetailScreen] instance.
  const BuyerInvoiceDetailScreen({
    super.key,
    required this.invoiceId,
  });

  @override
  State<BuyerInvoiceDetailScreen> createState() => _BuyerInvoiceDetailScreenState();
}

class _BuyerInvoiceDetailScreenState extends State<BuyerInvoiceDetailScreen> {
  final MarketplaceRepository _marketplaceRepository = ServiceLocator.marketplaceRepository;
  
  bool _isLoading = true;
  String? _errorMessage;
  Invoice? _invoice;
  Vendor? _vendor;

  @override
  void initState() {
    super.initState();
    
    // Use post-frame callback to show dialog after the first frame
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadInvoiceData();
    });
  }

  Future<void> _loadInvoiceData() async {
    // Set loading state
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });
    
    // Show loading dialog
    Logger.data('DEBUG: Showing loading dialog for invoice ${widget.invoiceId}');
    
    // Use a separate method to show the dialog to avoid context issues
    if (mounted) {
      // Use a global key for the loading dialog
      final GlobalKey<State> dialogKey = GlobalKey<State>();
      
      // Show the dialog
      showDialog(
        context: context,
        barrierDismissible: false,
        useRootNavigator: true, // Use root navigator to ensure dialog is on top
        builder: (BuildContext dialogContext) => LoadingDialog(
          key: dialogKey,
          message: 'Fetching invoice details...',
        ),
      );
      
      // Ensure the dialog is visible before proceeding
      await Future.delayed(const Duration(milliseconds: 100));
    }

    try {
      // Load invoice data
      final invoiceResult = await _marketplaceRepository.getInvoice(widget.invoiceId);
      
      // Dismiss the loading dialog
      Logger.data('DEBUG: Finished fetching invoice ${widget.invoiceId}, dismissing dialog');
      if (mounted && Navigator.of(context).canPop()) {
        Navigator.of(context).pop();
      }
      
      invoiceResult.fold(
        (failure) {
          setState(() {
            _isLoading = false;
            _errorMessage = failure.message ?? 'Failed to load invoice data';
          });
        },
        (invoice) async {
          // Set the invoice data and create a mock vendor
          setState(() {
            _invoice = invoice;
            
            // Create a mock vendor using the invoice's vendorId
            // This prevents null check errors when navigating to PaymentScreen
            _vendor = Vendor(
              id: invoice.vendorId.isNotEmpty ? invoice.vendorId : 'unknown',
              memberId: invoice.vendorId.isNotEmpty ? invoice.vendorId : 'unknown',
              businessName: 'Vendor', // Default name
              description: 'Vendor description',
              email: 'vendor@example.com',
              phone: '+1234567890',
              rating: 0.0,
              ratingCount: 0,
              isActive: true,
              createdAt: DateTime.now(),
              updatedAt: DateTime.now(),
            );
            
            _isLoading = false;
          });
          
          Logger.data('[INVOICE_DETAIL] Created mock vendor with ID: ${_vendor?.id}');
        },
      );
    } catch (e) {
      // Dismiss the loading dialog in case of error
      Logger.error('DEBUG: Error fetching invoice: $e, dismissing dialog');
      if (mounted && Navigator.of(context).canPop()) {
        Navigator.of(context).pop();
      }
      
      setState(() {
        _isLoading = false;
        _errorMessage = 'An unexpected error occurred: $e';
      });
    }
  }

  void _proceedToPayment() {
    if (_invoice == null) return;

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => PaymentScreen(
          invoice: _invoice!,
        ),
      ),
    ).then((result) {
      if (result == true) {
        // Payment was successful, refresh invoice data
        _loadInvoiceData();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Invoice Details'),
      ),
      body: _errorMessage != null
          ? _buildErrorView()
          : _invoice != null 
              ? _buildInvoiceDetails()
              : const SizedBox.shrink(), // Empty widget when loading (dialog is shown instead)
      bottomNavigationBar: _invoice != null && _invoice!.status == InvoiceStatus.pending
          ? _buildBottomBar()
          : null,
    );
  }

  Widget _buildErrorView() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              Icons.error_outline,
              size: 64,
              color: AppColors.errorRed,
            ),
            const SizedBox(height: 16),
            Text(
              _errorMessage!,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 16,
                color: AppColors.errorRed,
              ),
            ),
            const SizedBox(height: 24),
            FilledButton.icon(
              onPressed: _loadInvoiceData,
              icon: const Icon(Icons.refresh),
              label: const Text('Try Again'),
            ),
            const SizedBox(height: 16),
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Go Back'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInvoiceDetails() {
    return ListView(
      padding: const EdgeInsets.all(16.0),
      children: [
        _buildStatusBadge(),
        const SizedBox(height: 16),
        _buildVendorCard(),
        const SizedBox(height: 16),
        _buildInvoiceCard(),
        const SizedBox(height: 16),
        _buildLineItemsCard(),
      ],
    );
  }

  Widget _buildStatusBadge() {
    final status = _invoice!.status;
    Color color;
    IconData icon;
    String text;

    switch (status) {
      case InvoiceStatus.pending:
        color = AppColors.yellowPrimary;
        icon = Icons.pending;
        text = 'Pending Payment';
        break;
      case InvoiceStatus.paid:
        color = AppColors.successGreen;
        icon = Icons.check_circle;
        text = 'Paid';
        break;
      case InvoiceStatus.cancelled:
        color = AppColors.errorRed;
        icon = Icons.cancel;
        text = 'Cancelled';
        break;
      case InvoiceStatus.refunded:
        color = AppColors.primary;
        icon = Icons.replay;
        text = 'Refunded';
        break;
      case InvoiceStatus.failed:
        color = AppColors.errorRed;
        icon = Icons.error;
        text = 'Payment Failed';
        break;
    }

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        border: Border.all(color: color),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: color, size: 18),
          const SizedBox(width: 8),
          Text(
            text,
            style: TextStyle(
              color: color,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildVendorCard() {
    if (_vendor == null) return const SizedBox.shrink();

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Vendor',
              style: TextStyle(
                fontSize: 14,
                color: AppColors.textSecondary,
              ),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                CircleAvatar(
                  radius: 20,
                  backgroundColor: AppColors.primary.withOpacity(0.1),
                  backgroundImage: _vendor!.profileImageUrl != null
                      ? NetworkImage(_vendor!.profileImageUrl!)
                      : null,
                  child: _vendor!.profileImageUrl == null
                      ? const Icon(Icons.storefront, color: AppColors.primary)
                      : null,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _vendor!.businessName,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      if (_vendor!.rating > 0)
                        Row(
                          children: [
                            const Icon(
                              Icons.star,
                              size: 14,
                              color: AppColors.yellowPrimary,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              _vendor!.ratingDisplay,
                              style: const TextStyle(
                                fontSize: 12,
                                color: AppColors.textSecondary,
                              ),
                            ),
                          ],
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInvoiceCard() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Invoice Details',
              style: TextStyle(
                fontSize: 14,
                color: AppColors.textSecondary,
              ),
            ),
            const SizedBox(height: 12),
            _buildDetailRow('Invoice ID', _invoice!.id),
            const SizedBox(height: 8),
            _buildDetailRow(
              'Date',
              '${_invoice!.createdAt.day}/${_invoice!.createdAt.month}/${_invoice!.createdAt.year}',
            ),
            const SizedBox(height: 8),
            _buildDetailRow('Payment Method', _invoice!.paymentMethod),
            if (_invoice!.notes != null && _invoice!.notes!.isNotEmpty) ...[
              const SizedBox(height: 16),
              const Text(
                'Notes',
                style: TextStyle(
                  fontSize: 14,
                  color: AppColors.textSecondary,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                _invoice!.notes!,
                style: const TextStyle(
                  fontSize: 14,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 100,
          child: Text(
            label,
            style: const TextStyle(
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
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildLineItemsCard() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Items',
              style: TextStyle(
                fontSize: 14,
                color: AppColors.textSecondary,
              ),
            ),
            const SizedBox(height: 12),
            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: _invoice!.lineItems.length,
              separatorBuilder: (context, index) => const Divider(),
              itemBuilder: (context, index) {
                final item = _invoice!.lineItems[index];
                return Row(
                  children: [
                    Expanded(
                      flex: 3,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            item.productName,
                            style: const TextStyle(
                              fontWeight: FontWeight.w500,
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                          Text(
                            '${item.quantity} x ${_formatPrice(item.unitPrice, _invoice!.currency)}',
                            style: const TextStyle(
                              fontSize: 12,
                              color: AppColors.textSecondary,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Text(
                      _formatPrice(item.totalPrice, _invoice!.currency),
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                );
              },
            ),
            const Divider(thickness: 1),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Total',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  _invoice!.formattedTotalAmount,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: AppColors.primary,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  String _formatPrice(int price, String currency) {
    // Simple formatting for common currencies
    String symbol = '';
    switch (currency) {
      case 'USD':
        symbol = '\$';
        break;
      case 'EUR':
        symbol = '€';
        break;
      case 'GBP':
        symbol = '£';
        break;
      default:
        return '$currency ${price / 100}';
    }
    return '$symbol${price / 100}';
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
        child: Row(
          children: [
            Expanded(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Total',
                    style: TextStyle(
                      fontSize: 14,
                      color: AppColors.textSecondary,
                    ),
                  ),
                  Text(
                    _invoice!.formattedTotalAmount,
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: AppColors.primary,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            FilledButton.icon(
              icon: const Icon(Icons.payment),
              label: const Text('Sign and Pay'),
              onPressed: _proceedToPayment,
              style: FilledButton.styleFrom(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 12,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
