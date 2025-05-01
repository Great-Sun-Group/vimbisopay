import 'package:flutter/material.dart';
import 'package:vimbisopay_app/core/constants/url_constants.dart';
import 'package:vimbisopay_app/core/theme/app_colors.dart';
import 'package:vimbisopay_app/core/utils/logger.dart';
import 'package:vimbisopay_app/presentation/screens/marketplace/invoicing/buyer_invoice_detail_screen.dart';
import 'package:vimbisopay_app/presentation/screens/scan_qr_screen.dart';

/// A helper class for scanning and processing invoice QR codes.
class InvoiceQRScanner {
  final BuildContext _context;

  InvoiceQRScanner(this._context);

  /// Scans an invoice QR code and navigates to the invoice detail screen if valid.
  Future<void> scanInvoiceQR() async {
    try {
      // Navigate to the QR scanner screen
      final result = await Navigator.of(_context).push<String>(
        MaterialPageRoute(
          builder: (context) => const ScanQRScreen(
            showDebugOptions: false, // Disable debug options for production
          ),
          fullscreenDialog: true,
        ),
      );
      
      if (result != null) {
        String? invoiceId;
        
        // Check if the QR code is a valid invoice QR code in the old format
        if (result.startsWith(UrlConstants.invoiceDeepLinkPattern)) {
          // Extract the invoice ID from the QR code
          invoiceId = result.substring(UrlConstants.invoiceDeepLinkPattern.length);
          Logger.data('QR code scanned in old format: $result, extracted invoice ID: $invoiceId');
        } 
        // Check if the QR code is in the new URL format
        else if (result.startsWith(UrlConstants.invoiceUrlPattern)) {
          // Extract the invoice ID from the URL
          invoiceId = result.substring(UrlConstants.invoiceUrlPattern.length);
          Logger.data('QR code scanned in new format: $result, extracted invoice ID: $invoiceId');
        }
        
        if (invoiceId != null && invoiceId.isNotEmpty) {
          // Show loading indicator
          ScaffoldMessenger.of(_context).showSnackBar(
            const SnackBar(
              content: Text('Processing invoice...'),
              duration: Duration(seconds: 2),
            ),
          );
          
          // Navigate to the buyer invoice detail screen with the non-nullable invoiceId
          final String nonNullableInvoiceId = invoiceId; // Create a non-nullable copy
          Navigator.push(
            _context,
            MaterialPageRoute(
              builder: (context) => BuyerInvoiceDetailScreen(
                invoiceId: nonNullableInvoiceId,
              ),
            ),
          );
        } else {
          // Show error message for invalid QR code
          ScaffoldMessenger.of(_context).showSnackBar(
            const SnackBar(
              content: Text('Invalid invoice QR code'),
              backgroundColor: AppColors.errorRed,
            ),
          );
        }
      }
    } catch (e) {
      Logger.error('Error scanning invoice QR code', e);
      ScaffoldMessenger.of(_context).showSnackBar(
        SnackBar(
          content: Text('Error scanning QR code: $e'),
          backgroundColor: AppColors.errorRed,
        ),
      );
    }
  }
}
