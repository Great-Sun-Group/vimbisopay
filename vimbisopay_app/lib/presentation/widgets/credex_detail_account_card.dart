import 'package:flutter/material.dart';
import 'package:vimbisopay_app/core/theme/app_colors.dart';
import 'package:vimbisopay_app/domain/entities/dashboard.dart';
import 'package:vimbisopay_app/presentation/widgets/common/credit_rating_display.dart';

/// Widget for displaying an account card in credex detail with profile info and mini credit bar graph
class CredexDetailAccountCard extends StatelessWidget {
  final String? memberId;
  final String? firstName;
  final String? lastName;
  final String? handle;
  final int? tier;
  final String? profilePicture;
  final CreditRating? creditRating;
  final VoidCallback? onTap;
  final String? accountName;
  final String? accountHandle;
  final String? issuerAccountHandle;
  final bool useExpandedSpacing; // New parameter to control spacing
  final bool isSecured; // New parameter for secured/unsecured styling

  const CredexDetailAccountCard({
    super.key,
    this.memberId,
    this.firstName,
    this.lastName,
    this.handle,
    this.tier,
    this.profilePicture,
    this.creditRating,
    this.onTap,
    this.accountName,
    this.accountHandle,
    this.issuerAccountHandle,
    this.useExpandedSpacing = false, // Default to compact spacing
    this.isSecured = false, // Default to unsecured
  });

  String get displayName {
    if (firstName != null && lastName != null) {
      return '$firstName $lastName';
    }
    // Debug: Log when fallback is used
    if (firstName != null || lastName != null) {
      print(
          'CredexDetailAccountCard: Partial name data - firstName: $firstName, lastName: $lastName, accountName: $accountName');
    }
    return 'Unknown Member';
  }

  String _getInitials() {
    // Prioritize account information for account picture
    if (accountName != null && accountName!.isNotEmpty) {
      return accountName![0].toUpperCase();
    }
    if (accountHandle != null && accountHandle!.isNotEmpty) {
      return accountHandle![0].toUpperCase();
    }
    // Fallback to member name if no account info
    if (firstName != null && lastName != null) {
      return '${firstName![0]}${lastName![0]}'.toUpperCase();
    }
    if (firstName != null) {
      return firstName![0].toUpperCase();
    }
    if (lastName != null) {
      return lastName![0].toUpperCase();
    }
    return '?'; // Fallback
  }

  @override
  Widget build(BuildContext context) {
    // Debug logging for account name
    print(
        'CredexDetailAccountCard: accountName="$accountName", accountHandle="$accountHandle"');

    // Remove fixed width constraint to allow flexible sizing
    return SizedBox(
      child: Card(
        color: AppColors.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: BorderSide(
            color: isSecured ? AppColors.primary : AppColors.secondary,
            width: 2, // Thicker border
          ),
        ),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(12),
          child: Padding(
            padding: const EdgeInsets.all(12.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header with account name
                if (accountName != null && accountName!.isNotEmpty) ...[
                  Center(
                    child: Column(
                      children: [
                        Text(
                          accountName!,
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: isSecured ? AppColors.secondary : AppColors.primary,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          textAlign: TextAlign.center,
                        ),
                        if (accountHandle != null) ...[
                          SizedBox(height: useExpandedSpacing ? 4.0 : 2.0),
                          Row(
                            children: [
                              Icon(
                                Icons.credit_card,
                                size: 12,
                                color: isSecured ? AppColors.secondary : AppColors.primary,
                              ),
                              const SizedBox(width: 2),
                              Expanded(
                                child: Text(
                                  accountHandle!,
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w300, // Thin font
                                    color: isSecured ? AppColors.secondary : AppColors.primary,
                                    fontFamily: 'Roboto', // Narrow font family
                                  ),
                                  maxLines: 2,
                                  softWrap: true,
                                  textAlign: TextAlign.center,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ],
                    ),
                  ),
                  SizedBox(
                      height: useExpandedSpacing
                          ? 45.0
                          : 8.0), // Conditional spacing - more space above picture
                ],

                // Circular account picture placeholder
                Center(
                  child: Container(
                    width: 56,
                    height: 56,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(
                        color:
                            isSecured ? AppColors.primary : AppColors.secondary,
                        width: 1,
                      ),
                    ),
                    child: CircleAvatar(
                      backgroundColor: AppColors.background,
                      child: Text(
                        _getInitials(),
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: isSecured
                              ? AppColors.primary
                              : AppColors.secondary,
                        ),
                      ),
                    ),
                  ),
                ),
                // Only show credit rating for unsecured credex
                if (!isSecured) ...[
                  const SizedBox(height: 12),

                  // Simplified content section (credit rating bar only)
                  Builder(
                    builder: (context) {
                      // Debug logging for credit rating
                      if (creditRating != null) {
                        print(
                            'CredexDetailAccountCard: creditRating exists - redeemed: ${creditRating!.redeemedTotalUSD}, outstanding: ${creditRating!.outstandingTotalUSD}, defaulted: ${creditRating!.defaultedTotalUSD}, writtenOff: ${creditRating!.writtenOffTotalUSD}');
                      } else {
                        print('CredexDetailAccountCard: creditRating is null');
                      }

                      return CreditRatingDisplay(
                        creditRating: creditRating,
                        height: 24,
                        showDetailed: false,
                        showLegend: false,
                      );
                    },
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
