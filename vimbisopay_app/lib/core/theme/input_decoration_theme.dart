import 'package:flutter/material.dart';
import 'package:vimbisopay_app/core/theme/app_colors.dart';

final inputDecorationTheme = InputDecorationTheme(
  filled: true,
  fillColor: AppColors.surface,
  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
  border: OutlineInputBorder(
    borderRadius: BorderRadius.circular(8),
    borderSide: const BorderSide(color: AppColors.textSecondary),
  ),
  enabledBorder: OutlineInputBorder(
    borderRadius: BorderRadius.circular(8),
    borderSide: const BorderSide(color: AppColors.textSecondary),
  ),
  focusedBorder: OutlineInputBorder(
    borderRadius: BorderRadius.circular(8),
    borderSide: const BorderSide(color: AppColors.primary, width: 2),
  ),
  errorBorder: OutlineInputBorder(
    borderRadius: BorderRadius.circular(8),
    borderSide: const BorderSide(color: AppColors.error),
  ),
  focusedErrorBorder: OutlineInputBorder(
    borderRadius: BorderRadius.circular(8),
    borderSide: const BorderSide(color: AppColors.error, width: 2),
  ),
  labelStyle: const TextStyle(color: AppColors.textSecondary),
  helperStyle: const TextStyle(color: AppColors.textSecondary),
  errorStyle: const TextStyle(color: AppColors.error),
  prefixIconColor: AppColors.textSecondary,
);
