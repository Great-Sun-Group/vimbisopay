import 'dart:io';
import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:vimbisopay_app/core/theme/app_colors.dart';
import 'package:vimbisopay_app/core/utils/logger.dart';
import 'package:vimbisopay_app/domain/entities/marketplace/index.dart';

/// Helper class for store information screen
class StoreInformationHelper {
  /// Helper method to log the structure of a data object without exposing sensitive data
  static String getDataStructure(dynamic data, {int level = 0}) {
    if (data == null) {
      return 'null';
    }
    
    if (data is Map) {
      final keys = data.keys.map((k) {
        final value = data[k];
        if (value is Map) {
          return '$k: {${getDataStructure(value, level: level + 1)}}';
        } else if (value is List) {
          return '$k: [${value.length} items]';
        } else {
          return '$k: ${value.runtimeType}';
        }
      }).join(', ');
      return keys;
    } else if (data is List) {
      return '[${data.length} items]';
    } else {
      return data.runtimeType.toString();
    }
  }

  /// Formats a price with currency symbol and two decimal places.
  static String formatAccountBalance(double balance) {
    return '\$${balance.toStringAsFixed(2)}';
  }

  /// Builds an image widget from a URL, handling both local and remote URLs.
  static Widget buildImageFromUrl(String? imageUrl, {Widget? placeholder}) {
    if (imageUrl == null || imageUrl.isEmpty) {
      Logger.data('[STORE_INFO] Image URL is null or empty, using placeholder');
      return placeholder ?? Container(color: AppColors.grey300);
    }
    
    if (imageUrl.startsWith('file://')) {
      // Show local file image
      final filePath = imageUrl.substring(7); // Remove 'file://' prefix
      Logger.data('[STORE_INFO] Loading local image: $filePath');
      return Image.file(
        File(filePath),
        fit: BoxFit.cover,
        errorBuilder: (context, error, stackTrace) {
          Logger.error('[STORE_INFO] Error loading local image: $filePath', error);
          return placeholder ?? Container(color: AppColors.grey300);
        },
      );
    } else {
      // Show remote image
      Logger.data('[STORE_INFO] Loading remote image: $imageUrl');
      return CachedNetworkImage(
        imageUrl: imageUrl,
        fit: BoxFit.cover,
        placeholder: (context, url) => placeholder ?? Container(
          color: AppColors.grey200,
          child: const Center(child: CircularProgressIndicator()),
        ),
        errorWidget: (context, url, error) {
          Logger.error('[STORE_INFO] Error loading remote image: $url', error);
          return placeholder ?? Container(color: AppColors.grey300);
        },
      );
    }
  }
}
