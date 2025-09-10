import 'package:flutter/material.dart';
import 'package:vimbisopay_app/core/theme/app_colors.dart';
import 'package:vimbisopay_app/domain/entities/dashboard.dart';
import 'package:vimbisopay_app/presentation/widgets/common/credit_rating_display.dart';

/// Widget for displaying a member card with profile info and mini credit bar graph
class MemberCard extends StatelessWidget {
  final String? memberId;
  final String? firstName;
  final String? lastName;
  final String? handle;
  final int? tier;
  final String? profilePicture;
  final CreditRating? creditRating;
  final bool isCurrentUser;
  final VoidCallback? onTap;
  final String? accountName;
  final bool useExpandedSpacing; // New parameter to control spacing

  const MemberCard({
    super.key,
    this.memberId,
    this.firstName,
    this.lastName,
    this.handle,
    this.tier,
    this.profilePicture,
    this.creditRating,
    this.isCurrentUser = false,
    this.onTap,
    this.accountName,
    this.useExpandedSpacing = false, // Default to compact spacing
  });

  String get displayName {
    if (firstName != null && lastName != null) {
      return '$firstName $lastName';
    }
    return 'Unknown Member';
  }

  @override
  Widget build(BuildContext context) {
    // Debug logging for account name
    print('MemberCard: isCurrentUser=$isCurrentUser, accountName="$accountName"');

    // Remove fixed width constraint to allow flexible sizing
    return SizedBox(
      child: Card(
        color: AppColors.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: BorderSide(
            color: AppColors.primary.withOpacity(0.3),
            width: 1,
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
                    child: Text(
                      accountName!,
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: AppColors.primary,
                      ),
                      maxLines: 3,
                      overflow: TextOverflow.ellipsis,
                      textAlign: TextAlign.center,
                    ),
                  ),
                  SizedBox(height: useExpandedSpacing ? 45.0 : 8.0), // Conditional spacing - more space above picture
                ],

                // Profile section
                Column(
                  children: [
                    // Profile picture (centered)
                    Center(
                      child: Container(
                        width: 70,
                        height: 70,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: AppColors.darkBluePrimary,
                          border: Border.all(
                            color: isCurrentUser
                                ? AppColors.primary
                                : AppColors.textSecondary.withOpacity(0.3),
                            width: 2,
                          ),
                        ),
                        child: profilePicture != null
                            ? ClipOval(
                                child: Image.network(
                                  profilePicture!,
                                  fit: BoxFit.cover,
                                  errorBuilder: (context, error, stackTrace) =>
                                      Icon(
                                    Icons.person,
                                    color: AppColors.primary,
                                    size: 30,
                                  ),
                                ),
                              )
                            : Icon(
                                Icons.person,
                                color: AppColors.primary,
                                size: 30,
                              ),
                      ),
                    ),
                    SizedBox(height: useExpandedSpacing ? 24.0 : 8.0), // Conditional spacing - more space below picture

                    // Name and handle (centered)
                    Center(
                      child: Column(
                        children: [
                          Text(
                            displayName,
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                              color: AppColors.textPrimary,
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            textAlign: TextAlign.center,
                          ),
                          if (handle != null) ...[
                            SizedBox(height: useExpandedSpacing ? 8.0 : 2.0), // Conditional spacing
                            Text(
                              '@$handle',
                              style: TextStyle(
                                fontSize: 12,
                                color: AppColors.textSecondary,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              textAlign: TextAlign.center,
                            ),
                          ],
                        ],
                      ),
                    ),
                  ],
                ),

                SizedBox(height: useExpandedSpacing ? 32.0 : 16.0), // Conditional spacing

                // Mini credit bar graph
                Builder(
                  builder: (context) {
                    // Debug logging for credit rating
                    if (creditRating != null) {
                      print(
                          'MemberCard: creditRating exists - redeemed: ${creditRating!.redeemedTotalUSD}, outstanding: ${creditRating!.outstandingTotalUSD}, defaulted: ${creditRating!.defaultedTotalUSD}, writtenOff: ${creditRating!.writtenOffTotalUSD}');
                    } else {
                      print('MemberCard: creditRating is null');
                    }

                    return Column(
                      children: [
                        SizedBox(height: useExpandedSpacing ? 20.0 : 12.0), // Conditional spacing
                        CreditRatingDisplay(
                          creditRating: creditRating,
                          height: 16,
                          showDetailed: false,
                          showLegend: false,
                        ),
                      ],
                    );
                  },
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
