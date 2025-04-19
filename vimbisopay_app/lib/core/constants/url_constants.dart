import 'package:vimbisopay_app/core/config/api_config.dart';

/// Constants for URLs used in the app
class UrlConstants {
  /// Base URL for the API
  static String get apiBaseUrl => ApiConfig.baseUrl;

  /// URL pattern for invoice QR codes
  static const String invoiceUrlPattern = 'https://mycredex.app/getInvoice/';

  /// URL pattern for invoice deep links
  static const String invoiceDeepLinkPattern = 'vimbisopay://invoice/';

  /// URL pattern for storefront
  static const String storefrontUrlPattern = 'https://mycredex.app/storefront/';

  /// Private constructor to prevent instantiation
  UrlConstants._();
}
