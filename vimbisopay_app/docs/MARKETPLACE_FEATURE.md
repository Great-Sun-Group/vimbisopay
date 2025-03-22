# Vimbiso Market Feature

## Overview

The Vimbiso Market feature adds marketplace functionality to the VimbisoPay app by extending the underlying accounting infrastructure and client app capabilities. This feature is hidden behind a feature flag until it is completely implemented and ready for release.

## Feature Components

### 1. Vendor Profiles
- Enable members to create vendor profiles with product listings, images, and descriptions
- Manage vendor settings and profile information

### 2. Product Listings
- Allow vendors to list products with images, descriptions, and pricing information
- Browse and search product listings

### 3. Invoicing
- Generate invoices for purchases
- Facilitate payments through the credex system

## User Flows

### Vendor Flows
- Create and manage vendor profiles
- Add and edit product listings
- Manage inventory
- Process invoices and payments

### Purchaser Flows
- Browse the marketplace
- View products
- Make purchases
- Offer Credex for products

## Data Model

The Vimbiso Market system uses different types of accounts to track various aspects of the marketplace:
- Exchange Accounts
- Internal Accounts
- Asset Markers
- Invoices

### Account-Based Inventory System

The marketplace inventory system implements a double-entry accounting approach for tracking products and their value. This system treats each product as an account, enabling precise tracking of both quantity and value while maintaining consistency with accounting principles.

#### Double-Entry Accounting Paradigm

The system follows these key accounting principles:

1. **Product Accounts**
   - Each product (SKU) is represented as an account
   - Initial stock creates a positive balance (debit)
   - Sales create a negative balance (credit)
   - Account balance represents both quantity and value

2. **Value Addition Flow**
   ```
   Raw Materials Account    -$100 (credit)
   Processing Costs        -$50  (credit)
   Finished Product        +$150 (debit)
   ```

3. **Sales Flow**
   ```
   Product Account         -$120 (credit)
   Credex Account         +$120 (debit)
   ```

4. **Inventory Adjustments**
   - Spoilage:
     ```
     Product Account       -$30 (credit)
     Loss Account         +$30 (debit)
     ```
   - Damage:
     ```
     Product Account       -$25 (credit)
     Damage Account       +$25 (debit)
     ```

5. **Value Chain Tracking**
   - Raw materials → Processing → Finished goods
   - Each transformation creates corresponding debits and credits
   - Full audit trail of value addition process

#### Benefits of This Approach


1. **Unified Accounting**: Products and inventory are integrated directly into the accounting system
2. **Consistent Transactions**: Inventory movements use the same transaction mechanisms as financial transactions
3. **Simplified Reconciliation**: Easier to reconcile inventory with financial records
4. **Scalable Architecture**: Leverages existing infrastructure for new functionality

#### Conceptual Mapping

| Traditional Concept | Account-Based Approach |
|---------------------|------------------------|
| Product/SKU | Internal Account (PRODUCTION type) |
| Inventory | Account Balance |
| Adding Stock | Credit Transaction to Account |
| Removing Stock | Debit Transaction from Account |
| Product Categories | Account Metadata/Tags |
| Product Images | AssetMarkers linked to Account |

#### Inventory Flow

1. **Create SKU**: Create an internal account with type PRODUCTION
2. **Add Inventory**: Credit the account with initial stock
3. **Sell Product**: Debit the account when items are sold
4. **Restock**: Credit the account when new inventory arrives
5. **Adjust Inventory**: Credit/debit for inventory adjustments

### Entity Relationships

```
┌─────────────┐       ┌─────────────┐       ┌─────────────┐
│    Member   │───┐   │   Internal  │       │   Invoice   │
│             │   │   │   Account   │       │             │
└─────────────┘   │   │   (SKU)     │       └──────┬──────┘
                  │   └──────┬──────┘              │
                  │          │                     │
                  ▼          │                     │
┌─────────────┐   │   ┌──────▼──────┐       ┌──────▼──────┐
│    Vendor   │◄──┘   │ AssetMarker │◄──────│ Transaction │
│             │       │             │       │             │
└─────────────┘       └─────────────┘       └─────────────┘
```

### Entity Details

#### Member
- Represents a user in the system
- Can be associated with a vendor profile
- Has authentication and personal information

#### Vendor
- Represents a seller in the marketplace
- Associated with a member
- Has business information, ratings, and product listings

#### Internal Account (SKU)
- Represents a product or service for sale
- Has type PRODUCTION for inventory tracking
- Contains metadata for product details (name, description, price, etc.)
- Account balance represents current inventory level
- Associated with a vendor

#### AssetMarker
- Represents digital assets like product images
- Used to track ownership and transfers
- Links to internal accounts (SKUs)

#### Invoice
- Represents a purchase transaction
- Contains line items, payment status, and buyer/seller information
- Links to transactions in the accounting system

#### Transaction
- Represents the movement of value or inventory in the system
- Records transfers between accounts
- Links to invoices and asset markers

## API Endpoints

### Member Endpoints
- `GET /api/members/{id}` - Get member profile
- `PUT /api/members/{id}` - Update member profile
- `GET /api/members/{id}/vendor` - Get vendor profile for member
- `POST /api/members/{id}/vendor` - Create vendor profile for member
- `PUT /api/members/{id}/vendor` - Update vendor profile

### Account Endpoints (for Inventory Management)
- `/editAccount` - Update an existing exchange account's details
- `/createAccountInternal` - Create a new internal account for tracking products (SKUs)
- `/editAccountInternal` - Update an existing internal account's details
- `/deleteAccountInternal` - Delete an internal account

### AssetMarker Endpoints
- `/addAssetMarker` - Create a new asset marker in the system
- `/uploadAndOptimizeJpg` - Upload a JPG image and create asset markers
- `/connectAsset` - Connect an asset marker to another node
- `/disconnectAsset` - Remove a relationship between an asset marker and another node
- `GET /api/assetmarkers/{id}` - Get asset marker details
- `GET /api/products/{id}/assetmarker` - Get asset marker for product

### Invoice Endpoints
- `/generateInvoice` - Generate an invoice for a transaction
- `GET /api/invoices` - List invoices (with filtering)
- `GET /api/invoices/{id}` - Get invoice details
- `PUT /api/invoices/{id}` - Update invoice
- `GET /api/invoices/{id}/transactions` - Get transactions for invoice

## UI Specifications

### Vendor Screens

#### Vendor Profile Screen
- Business information (name, description, contact details)
- Profile image and banner
- Rating and reviews
- Settings for payment preferences

#### Inventory Management Screen
- List of vendor's SKUs (internal accounts)
- Add/edit SKU functionality with metadata
- SKU status (active/inactive)
- Inventory tracking and adjustment
- Transaction history for each SKU

#### Transaction History Screen
- List of sales and purchases
- Filter by date, status, product
- Invoice details

### Purchaser Screens

#### Marketplace Browse Screen
- Product grid/list with images and basic info
- Search functionality
- Category filtering
- Featured products section

#### Product Detail Screen
- Product images (gallery view)
- Detailed description
- Price information
- Vendor details
- "Buy Now" and "Make Offer" buttons

#### Checkout Screen
- Order summary
- Payment method selection
- Credex balance display
- Confirmation step

## Feature Flag Implementation

The marketplace feature is hidden behind a feature flag until it is completely implemented. The feature flag is implemented using Firebase Remote Config with support for local overrides for development and testing.

### Feature Flag Key
```
enable_marketplace
```

### Default Value
```
false
```

### Implementation Details
- The feature flag controls the visibility of the marketplace tab in the bottom navigation bar
- When enabled, users can access the marketplace functionality
- When disabled, the marketplace tab is hidden and the functionality is not accessible
- Local overrides can be set for development and testing purposes

### Enhanced Feature Flag Service

The `FeatureFlagService` has been enhanced to support local overrides for testing:

```dart
/// Checks if the marketplace feature is enabled.
///
/// Returns true if the marketplace feature is enabled, false otherwise.
/// If a local override is set, it takes precedence over the remote config value.
bool isMarketplaceEnabled() {
  // Check if there's a local override
  if (_prefs.containsKey(_marketplaceOverrideKey)) {
    final localOverride = _prefs.getBool(_marketplaceOverrideKey);
    Logger.data('Using local override for marketplace feature: $localOverride');
    return localOverride ?? _remoteConfig.getBool(FeatureFlags.enableMarketplace);
  }
  
  // Otherwise use the remote config value
  return _remoteConfig.getBool(FeatureFlags.enableMarketplace);
}

/// Sets a local override for the marketplace feature flag.
Future<bool> setMarketplaceOverride(bool enabled) async {
  // Implementation details...
}

/// Clears the local override for the marketplace feature flag.
Future<bool> clearMarketplaceOverride() async {
  // Implementation details...
}

/// Checks if there's a local override for the marketplace feature flag.
bool hasMarketplaceOverride() {
  // Implementation details...
}

/// Gets the value of the local override for the marketplace feature flag.
bool? getMarketplaceOverrideValue() {
  // Implementation details...
}
```

### Service Locator Changes

The `ServiceLocator` has been updated to properly initialize the feature flag service:

```dart
// Lazy-initialized services that require async initialization
static FeatureFlagService? _featureFlagService;

// Getter for FeatureFlagService with lazy initialization
static FeatureFlagService get featureFlagService {
  if (_featureFlagService == null) {
    throw Exception('FeatureFlagService not initialized. Call initializeFeatureFlagService() first.');
  }
  return _featureFlagService!;
}

// Initialize FeatureFlagService
static Future<FeatureFlagService> initializeFeatureFlagService() async {
  if (_featureFlagService != null) {
    return _featureFlagService!;
  }
  
  final prefs = await SharedPreferences.getInstance();
  _featureFlagService = FeatureFlagService(_remoteConfig, prefs);
  return _featureFlagService!;
}
```

### Code Implementation

The feature flag is checked in several key places:

1. **Bottom Navigation Bar** (`home_action_buttons.dart`)
   ```dart
   // Check if marketplace feature is enabled
   final bool isMarketplaceEnabled = ServiceLocator.featureFlagService.isMarketplaceEnabled();
   
   // Add marketplace tab if feature is enabled
   if (isMarketplaceEnabled) {
     items.add(
       BottomNavigationBarItem(
         icon: Container(
           padding: const EdgeInsets.all(8),
           decoration: BoxDecoration(
             shape: BoxShape.circle,
             color: AppColors.primary.withOpacity(0.1),
           ),
           child: const Icon(Icons.storefront_outlined),
         ),
         label: 'Market',
       ),
     );
   }
   ```

2. **Route Protection** (`main.dart`)
   ```dart
   if (settings.name == '/marketplace') {
     // Only allow access if the marketplace feature is enabled
     if (ServiceLocator.featureFlagService.isMarketplaceEnabled()) {
       return MaterialPageRoute(
         builder: (context) => const MarketplaceScreen(),
         settings: settings,
       );
     } else {
       // Redirect to home if marketplace is not enabled
       Logger.state('Marketplace feature is disabled, redirecting to home');
       return MaterialPageRoute(
         builder: (context) => const HomeScreen(),
       );
     }
   }
   ```

   Additional route protection has been added for vendor-related screens:

   ```dart
   // Vendor profile screen route
   if (settings.name == '/vendor-profile') {
     // Only allow access if the marketplace feature is enabled
     if (ServiceLocator.featureFlagService.isMarketplaceEnabled()) {
       final args = settings.arguments as Map<String, dynamic>?;
       if (args == null || !args.containsKey('vendorId')) {
         Logger.error('No vendor ID provided for vendor-profile route');
         return MaterialPageRoute(
           builder: (context) => const MarketplaceScreen(),
         );
       }
       
       return MaterialPageRoute(
         builder: (context) => VendorProfileScreen(
           vendorId: args['vendorId'] as String,
           isOwner: args['isOwner'] as bool? ?? false,
         ),
         settings: settings,
       );
     } else {
       // Redirect to home if marketplace is not enabled
       Logger.state('Marketplace feature is disabled, redirecting to home');
       return MaterialPageRoute(
         builder: (context) => const HomeScreen(),
       );
     }
   }
   
   // Vendor registration screen route
   if (settings.name == '/vendor-registration') {
     // Only allow access if the marketplace feature is enabled
     if (ServiceLocator.featureFlagService.isMarketplaceEnabled()) {
       final args = settings.arguments as Map<String, dynamic>?;
       if (args == null || !args.containsKey('memberId')) {
         Logger.error('No member ID provided for vendor-registration route');
         return MaterialPageRoute(
           builder: (context) => const HomeScreen(),
         );
       }
       
       return MaterialPageRoute(
         builder: (context) => VendorRegistrationScreen(
           memberId: args['memberId'] as String,
         ),
         settings: settings,
       );
     } else {
       // Redirect to home if marketplace is not enabled
       Logger.state('Marketplace feature is disabled, redirecting to home');
       return MaterialPageRoute(
         builder: (context) => const HomeScreen(),
       );
     }
   }
   ```

3. **Profile Integration** (`profile_settings_screen.dart`)
   ```dart
   // Marketplace Settings Section (only if feature flag is enabled)
   if (ServiceLocator.featureFlagService.isMarketplaceEnabled()) ...[
     _buildMarketplaceSection(),
     const SizedBox(height: 24),
   ],
   ```

   The profile screen checks if the user is a vendor and shows the appropriate UI:

   ```dart
   Widget _buildMarketplaceSection() {
     return SettingsContainer(
       title: 'Marketplace Settings',
       children: [
         Padding(
           padding: const EdgeInsets.all(16.0),
           child: Column(
             crossAxisAlignment: CrossAxisAlignment.start,
             children: [
               const Text(
                 'Sell your products and services in the Vimbiso Marketplace.',
                 style: TextStyle(
                   fontSize: 14,
                   color: AppColors.textSecondary,
                 ),
               ),
               const SizedBox(height: 16),
               
               if (_isCheckingVendorStatus)
                 const Center(
                   child: CircularProgressIndicator(),
                 )
               else if (_isVendor)
                 ListTile(
                   title: const Text('Manage Vendor Profile'),
                   subtitle: const Text('Edit your business information and products'),
                   trailing: const Icon(Icons.chevron_right),
                   onTap: _navigateToVendorProfile,
                 )
               else
                 ListTile(
                   title: const Text('Become a Vendor'),
                   subtitle: const Text('Create a vendor profile to sell in the marketplace'),
                   trailing: const Icon(Icons.chevron_right),
                   onTap: _navigateToVendorRegistration,
                 ),
             ],
           ),
         ),
       ],
     );
   }
   ```

4. **Enhanced Debug Screen** (`debug_screen.dart`)
   - Shows current status of the marketplace feature flag
   - Displays both default and remote values
   - Provides button to force refresh Remote Config
   - Allows toggling the marketplace feature flag locally
   - Shows local override status with visual indicator
   - Provides button to clear local override

   ```dart
   Card(
     color: AppColors.surface,
     child: Padding(
       padding: const EdgeInsets.all(16.0),
       child: Column(
         crossAxisAlignment: CrossAxisAlignment.start,
         children: [
           Row(
             mainAxisAlignment: MainAxisAlignment.spaceBetween,
             children: [
               const Text('Marketplace Feature'),
               Switch(
                 value: _marketplaceEnabled,
                 onChanged: (value) async {
                   // Set local override
                   await ServiceLocator.featureFlagService.setMarketplaceOverride(value);
                 },
               ),
             ],
           ),
           Row(
             children: [
               Text(_marketplaceEnabled ? 'Enabled' : 'Disabled'),
               if (_hasLocalOverride) ...[
                 Container(
                   padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                   child: const Text('Local Override'),
                 ),
               ],
             ],
           ),
           if (_hasLocalOverride) ...[
             TextButton.icon(
               icon: const Icon(Icons.delete_outline),
               label: const Text('Clear Override'),
               onPressed: () async {
                 // Clear local override
                 await ServiceLocator.featureFlagService.clearMarketplaceOverride();
               },
             ),
           ],
         ],
       ),
     ),
   ),
   ```

5. **Marketplace Screen Integration** (`marketplace_screen.dart`)
   
   The marketplace screen now navigates to vendor profiles when products are tapped:

   ```dart
   Widget _buildProductCard(Product product) {
     return Card(
       child: InkWell(
         onTap: () async {
           // Get the vendor for this product
           final vendorResult = await _marketplaceRepository.getVendor(product.vendorId);
           
           vendorResult.fold(
             (failure) {
               ScaffoldMessenger.of(context).showSnackBar(
                 SnackBar(content: Text('Failed to load vendor')),
               );
             },
             (vendor) {
               // Navigate to vendor profile screen
               Navigator.pushNamed(
                 context,
                 '/vendor-profile',
                 arguments: {
                   'vendorId': vendor.id,
                   'isOwner': false,
                 },
               );
             },
           );
         },
         child: // Product card content
       ),
     );
   }
   ```

## Implementation Plan

### Phase 1: Data Models and API Integration (1-2 weeks)

1. **Create Entity Classes**
   - Create `Vendor` entity
   - Create `Internal Account` entity for SKUs
   - Create `Invoice` entity
   - Create `AssetMarker` entity

2. **Implement Repositories**
   - Create `MarketplaceRepository` interface
   - Implement `MarketplaceRepositoryImpl` with API integration
   - Add methods for vendor, account, and invoice management
   - Implement account-based inventory management

3. **Update Service Locator**
   - Add marketplace repository to `ServiceLocator`
   - Add account repository integration

### Phase 2: UI Implementation (2-3 weeks)

1. **Vendor Profile UI**
   - Create vendor profile screen
   - Implement vendor profile editing
   - Add vendor settings

2. **Inventory Management UI**
   - Create SKU management screen
   - Implement internal account creation/editing
   - Add inventory tracking and adjustment
   - Implement product metadata management
   - Add product search and filtering

3. **Marketplace Browse UI**
   - Enhance marketplace screen with product grid/list
   - Implement product detail view
   - Add search and category filtering

4. **Invoicing UI**
   - Create invoice generation screen
   - Implement payment flow
   - Add invoice history view

### Phase 3: Feature Integration (1-2 weeks)

1. **Connect with Credex System**
   - Integrate marketplace transactions with existing credex system
   - Implement payment processing

2. **Notifications**
   - Add marketplace-related notifications
   - Implement notification handling for new orders, payments, etc.

3. **Analytics**
   - Add analytics events for marketplace actions
   - Track user engagement with marketplace features

### Phase 4: Testing and Documentation (1 week)

1. **Testing**
   - Write unit tests for marketplace models and repositories
   - Write widget tests for marketplace UI components
   - Perform integration testing with feature flag enabled/disabled

2. **Documentation**
   - Update implementation documentation
   - Document API endpoints and data models
   - Create user guide for marketplace features

## Vendor Profile Implementation

### Vendor Profile Screen

The `VendorProfileScreen` displays a vendor's profile information, including business details, contact information, ratings, and products. It is implemented as a separate screen from the existing profile screen to ensure that the existing profile functionality continues to work for members who are not vendors.

Key features:
- Banner image with gradient overlay for better text visibility
- Profile image with fallback to icon if no image is available
- Business name and rating display
- About section with business description
- Contact information section
- Products section with grid view of products
- Empty state for when a vendor has no products
- Owner-specific actions (edit profile, add product, etc.)

```dart
class VendorProfileScreen extends StatefulWidget {
  /// The ID of the vendor to display.
  final String vendorId;

  /// Whether the current user is the owner of this vendor profile.
  final bool isOwner;

  // ...
}
```

### Vendor Registration Screen

The `VendorRegistrationScreen` allows users to create a vendor profile to sell products in the marketplace. It is accessible from the profile settings screen for users who are not yet vendors.

Key features:
- Form for entering business information (name, description)
- Form for entering contact information (email, phone)
- Terms and conditions section
- Submit button to create vendor profile
- Navigation to vendor profile screen after successful creation

```dart
class VendorRegistrationScreen extends StatefulWidget {
  /// The ID of the member creating a vendor profile.
  final String memberId;

  // ...
}
```

### Profile Integration

The marketplace feature is integrated with the user profile through the `ProfileSettingsScreen`. The screen checks if the user is a vendor and shows the appropriate UI:

- If the user is a vendor, it shows a "Manage Vendor Profile" button
- If the user is not a vendor, it shows a "Become a Vendor" button
- The section is only visible if the marketplace feature flag is enabled

```dart
Future<void> _checkVendorStatus(String memberId) async {
  try {
    setState(() {
      _isCheckingVendorStatus = true;
    });

    final marketplaceRepository = ServiceLocator.marketplaceRepository;
    final isVendor = await marketplaceRepository.isMemberVendor(memberId);

    if (mounted) {
      setState(() {
        _isVendor = isVendor;
        _isCheckingVendorStatus = false;
      });
    }
  } catch (e) {
    Logger.error('Error checking vendor status', e);
    if (mounted) {
      setState(() {
        _isVendor = false;
        _isCheckingVendorStatus = false;
      });
    }
  }
}
```

## Testing Strategy

### 1. Unit Testing

- **Models**: Test serialization/deserialization of marketplace entities
- **Repositories**: Test API integration with mock HTTP client
- **Services**: Test business logic for marketplace operations
- **Feature Flag Service**: Test local override functionality

### 2. Widget Testing

- Test marketplace UI components in isolation
- Verify conditional rendering based on feature flag
- Test user interactions with marketplace screens
- Test vendor profile and registration screens

### 3. Integration Testing

- Test complete user flows with feature flag enabled
- Verify marketplace integration with credex system
- Test error handling and edge cases
- Test navigation between marketplace screens

### 4. Feature Flag Testing

#### Local Testing
- Test with default values (marketplace disabled)
- Use the Debug screen to toggle the feature flag locally
- Verify UI elements appear/disappear correctly
- Test clearing local overrides

#### Remote Testing
- Update Firebase Remote Config values in the Firebase Console
- Verify the app responds correctly to remote changes
- Test feature flag refresh functionality
- Verify local overrides take precedence over remote values

### 5. Debug Screen Testing

The Debug screen has been enhanced to allow toggling the marketplace feature flag locally for testing:

- Toggle switch to enable/disable the marketplace feature
- Visual indicator for local override status
- Button to clear local override
- Display of default, remote, and local override values

## Rollout Strategy

1. **Development Phase**
   - Keep feature flag disabled by default
   - Enable locally for development and testing
   - Use debug screen to toggle feature flag for testing

2. **Testing Phase**
   - Enable feature flag for internal testers via Firebase Remote Config
   - Collect feedback and make improvements

3. **Gradual Rollout**
   - Enable for 10% of users and monitor analytics
   - Increase to 25%, then 50%, then 100% as confidence grows
   - Monitor error rates and user feedback at each stage

4. **Full Release**
   - Enable feature flag for all users
   - Consider removing feature flag once stable

## Monitoring and Analytics

- Track marketplace engagement metrics
- Monitor error rates for marketplace features
- Collect user feedback on marketplace experience
- Analyze transaction patterns and popular products

## Invoicing UI Implementation

### Transaction Flow

The marketplace invoicing system follows a point-of-sale (POS) flow where the vendor initiates the process:

#### Vendor-Side Flow
1. **Open Tab**: Vendor opens a new sales tab for a buyer
2. **Add Items**: Vendor selects products and adds them to the basket
3. **Generate Invoice**: Vendor finalizes the basket and generates an invoice
4. **Share Invoice**: System generates a QR code for the buyer to scan

#### Buyer-Side Flow
1. **Scan Invoice**: Buyer scans the QR code (containing invoice ID or deep link)
2. **Fetch Invoice**: App fetches invoice details from the API
3. **Review & Confirm**: Buyer reviews the invoice details
4. **Initiate Payment**: Buyer initiates a credex payment offer

#### Completion Flow
1. **Vendor Notification**: Vendor receives notification of pending payment
2. **Accept Payment**: Vendor reviews and accepts the credex payment
3. **Complete Transaction**: System updates invoice status and creates asset markers

### Required Screens

#### Vendor Screens

##### Vendor Sales Tab Screen
- Interface for creating a new sales transaction
- Product selection from vendor's inventory
- Quantity adjustment and price display
- Basket summary with total calculation
- Button to generate invoice

##### Invoice Generation Screen
- Final review of items before generating invoice
- Option to add buyer information (if known)
- Option to add notes
- Generate button to create the invoice
- QR code display for buyer to scan

##### Vendor Invoice List Screen
- List of all invoices created by the vendor
- Filter by status (pending, paid, cancelled)
- Search functionality
- Quick actions (view details, cancel, etc.)

##### Payment Acceptance Screen
- Notification of pending payment
- Details of the payment offer
- Accept/Reject buttons
- Confirmation of successful payment

#### Buyer Screens

##### QR Scanner Screen
- Camera interface for scanning invoice QR code
- Error handling for invalid QR codes
- Loading state while fetching invoice

##### Invoice Detail Screen
- Display of all invoice information
- List of items with quantities and prices
- Total amount and payment status
- Button to initiate payment

##### Payment Initiation Screen
- Selection of credex account to pay from
- Confirmation of payment amount
- Option to add a note
- Submit payment offer button

##### Buyer Invoice List Screen
- History of invoices for the buyer
- Filter by status
- Search functionality
- Quick actions (view details, pay, etc.)

### Key Components

#### Basket Component
- List of selected products with quantities
- Price calculation
- Add/remove/edit functionality
- Empty state handling

#### QR Code Generator/Scanner
- Generate QR code containing invoice ID or deep link
- Scan and parse QR codes
- Error handling for invalid codes

#### Invoice Card
- Reusable component for displaying invoice summary
- Shows vendor/buyer info, date, amount, and status
- Visual indicators for different statuses

#### Payment Flow Components
- Account selector for payment
- Confirmation dialog
- Success/failure states

### API Integration

#### New Repository Methods Needed
- `createSalesTab()` - Create a new sales session
- `addItemToBasket()` - Add product to current sales tab
- `removeItemFromBasket()` - Remove product from current sales tab
- `generateInvoiceQR()` - Generate QR code for an invoice
- `getInvoiceByQR()` - Fetch invoice from QR code data
- `createCredexOffer()` - Create a payment offer for an invoice
- `acceptCredexOffer()` - Accept a payment offer

#### Existing Repository Methods to Use
- `getInvoice(String id)`
- `getInvoicesByBuyer(String buyerId)`
- `getInvoicesByVendor(String vendorId)`
- `createInvoice(...)`
- `updateInvoice(...)`

### Implementation Approach

#### Phase 1: Vendor Sales Flow
- Create the Vendor Sales Tab Screen
- Implement basket functionality
- Build invoice generation process
- Create QR code generation

#### Phase 2: Buyer Payment Flow
- Implement QR code scanner
- Create invoice detail view for buyers
- Build payment initiation screen
- Implement credex offer creation

#### Phase 3: Payment Completion
- Create vendor notification system
- Implement payment acceptance flow
- Build status update mechanism
- Create asset marker generation

#### Phase 4: Invoice Management
- Implement invoice lists for both buyer and vendor
- Add filtering and search functionality
- Create detailed invoice history views
- Implement invoice status tracking

### Technical Considerations

#### QR Code Implementation
- Use `qr_flutter` package for generating QR codes
- Use `mobile_scanner` or similar for scanning QR codes
- Encode invoice ID or deep link URL in QR code
- Handle app-to-app deep linking

#### Real-time Updates
- Consider using WebSockets or Firebase for real-time payment notifications
- Implement polling as a fallback for status updates
- Handle offline scenarios gracefully

#### Security Considerations
- Ensure invoice QR codes are secure and can't be tampered with
- Validate all payment requests on the server
- Implement proper authentication for all API calls
- Consider adding expiration to invoices

#### User Experience
- Provide clear feedback at each step of the process
- Add loading indicators for network operations
- Implement error recovery mechanisms
- Design for accessibility

### Dependencies

The following packages will be needed for the invoicing UI implementation:

```yaml
dependencies:
  # QR code generation
  qr_flutter: ^4.1.0
  
  # QR code scanning
  mobile_scanner: ^3.5.0
  
  # State management (if needed beyond StatefulWidget)
  provider: ^6.0.5
  
  # For deep linking
  uni_links: ^0.5.1
  
  # For formatting currency
  intl: ^0.18.1
```
