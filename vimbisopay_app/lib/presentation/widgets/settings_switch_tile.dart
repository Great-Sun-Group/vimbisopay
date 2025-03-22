import 'package:flutter/material.dart';
import 'package:vimbisopay_app/presentation/widgets/settings_container.dart';

class SettingsSwitchTile extends StatelessWidget {
  final String title;
  final String subtitle;
  final IconData icon;
  final bool value;
  final ValueChanged<bool> onChanged;
  final bool showDivider;

  const SettingsSwitchTile({
    super.key,
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.value,
    required this.onChanged,
    this.showDivider = true,
  });

  @override
  Widget build(BuildContext context) {
    return SettingsListTile(
      title: title,
      subtitle: subtitle,
      icon: icon,
      showDivider: showDivider,
      trailing: AnimatedSwitcher(
        duration: const Duration(milliseconds: 200),
        transitionBuilder: (Widget child, Animation<double> animation) {
          return FadeTransition(
            opacity: animation,
            child: child,
          );
        },
        child: Switch(
          key: ValueKey(value),
          value: value,
          onChanged: onChanged,
          activeColor: Theme.of(context).colorScheme.secondary,
        ),
      ),
    );
  }
}
