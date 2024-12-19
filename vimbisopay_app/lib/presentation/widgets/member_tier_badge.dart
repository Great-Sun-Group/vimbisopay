import 'package:flutter/material.dart';
import 'package:vimbisopay_app/core/theme/app_colors.dart';
import 'package:vimbisopay_app/domain/entities/dashboard.dart';
import 'package:vimbisopay_app/presentation/constants/home_constants.dart';

class MemberTierBadge extends StatelessWidget {
  final MemberTierType tierType;

  const MemberTierBadge({
    super.key,
    required this.tierType,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: _getBadgeColor(),
        borderRadius: BorderRadius.circular(HomeConstants.cardBorderRadius),
        border: Border.all(
          color: tierType == MemberTierType.hustler ? AppColors.success : Colors.white,
          width: 2,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Text(
        _getTierLabel(),
        style: const TextStyle(
          color: Colors.white,
          fontSize: 10,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  Color _getBadgeColor() {
    switch (tierType) {
      case MemberTierType.hustler:
        return AppColors.primary;
      case MemberTierType.open:
      default:
        return AppColors.surface;
    }
  }

  String _getTierLabel() {
    switch (tierType) {
      case MemberTierType.hustler:
        return 'HUSTLER';
      case MemberTierType.open:
      default:
        return 'FREE';
    }
  }
}
