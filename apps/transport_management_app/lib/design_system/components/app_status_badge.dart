import 'package:flutter/material.dart';

import '../app_design_tokens.dart';

enum AppStatusTone { neutral, information, success, warning, danger }

class AppStatusBadge extends StatelessWidget {
  const AppStatusBadge({
    required this.label,
    required this.tone,
    this.icon,
    super.key,
  });

  final String label;
  final AppStatusTone tone;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    final color = switch (tone) {
      AppStatusTone.information => context.tokens.information,
      AppStatusTone.success => context.tokens.success,
      AppStatusTone.warning => context.tokens.warning,
      AppStatusTone.danger => context.tokens.danger,
      AppStatusTone.neutral => context.tokens.textMuted,
    };
    return Semantics(
      label: label,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: color.withValues(alpha: .1),
          borderRadius: BorderRadius.circular(context.tokens.radiusLarge),
          border: Border.all(color: color.withValues(alpha: .35)),
        ),
        child: Padding(
          padding: EdgeInsetsDirectional.symmetric(
            horizontal: context.tokens.space3,
            vertical: context.tokens.space1,
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (icon != null) ...[
                Icon(icon, size: 16, color: color),
                SizedBox(width: context.tokens.space1),
              ],
              Text(
                label,
                style: Theme.of(context).textTheme.labelMedium?.copyWith(
                  color: color,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
