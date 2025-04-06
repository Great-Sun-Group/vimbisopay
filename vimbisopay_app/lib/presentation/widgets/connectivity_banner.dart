import 'package:flutter/material.dart';
import 'package:vimbisopay_app/core/theme/app_colors.dart';
import 'package:vimbisopay_app/infrastructure/services/service_locator.dart';

class ConnectivityBanner extends StatelessWidget {
  const ConnectivityBanner({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<bool>(
      stream: ServiceLocator.connectivityService.connectivityStream,
      initialData: ServiceLocator.connectivityService.isConnected,
      builder: (context, snapshot) {
        final isConnected = snapshot.data ?? true;
        
        return AnimatedContainer(
          duration: const Duration(milliseconds: 300),
          height: isConnected ? 0 : 36,
          width: double.infinity,
          color: AppColors.error,
          child: isConnected 
              ? const SizedBox.shrink() 
              : const _BannerContent(),
        );
      },
    );
  }
}

class _BannerContent extends StatelessWidget {
  const _BannerContent({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(
            Icons.wifi_off,
            color: Colors.white,
            size: 16,
          ),
          const SizedBox(width: 8),
          Text(
            'No internet connection',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: Colors.white,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}

class ConnectivityWrapper extends StatelessWidget {
  final Widget child;
  final bool showBannerOnTop;

  const ConnectivityWrapper({
    Key? key,
    required this.child,
    this.showBannerOnTop = true,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        if (showBannerOnTop) const ConnectivityBanner(),
        Expanded(child: child),
        if (!showBannerOnTop) const ConnectivityBanner(),
      ],
    );
  }
}
