import 'package:flutter/material.dart';

import '../app_design_tokens.dart';
import '../app_motion.dart';

/// A compact command-center panel. It owns visual treatment only; callers own
/// all domain state and interaction behavior.
class AtlasCommandSurface extends StatelessWidget {
  const AtlasCommandSurface({
    required this.child,
    this.padding,
    this.accent = false,
    this.backgroundColor,
    super.key,
  });

  final Widget child;
  final EdgeInsetsGeometry? padding;
  final bool accent;
  final Color? backgroundColor;

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: backgroundColor ?? tokens.commandSurface,
        borderRadius: BorderRadius.circular(tokens.radiusSmall),
        border: Border.all(
          color: accent ? tokens.commandAccent : tokens.commandBorder,
          width: tokens.borderThin,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: .18),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Padding(
        padding: padding ?? EdgeInsets.all(tokens.space3),
        child: child,
      ),
    );
  }
}

class AtlasKpiItem extends StatelessWidget {
  const AtlasKpiItem({
    required this.label,
    required this.value,
    required this.unavailableLabel,
    required this.icon,
    this.tone,
    super.key,
  });

  final String label;
  final int? value;
  final String unavailableLabel;
  final IconData icon;
  final Color? tone;

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    final color = tone ?? tokens.commandAccent;
    final displayValue = value?.toString() ?? '—';
    return Semantics(
      label: '$label: ${value == null ? unavailableLabel : displayValue}',
      child: Padding(
        padding: EdgeInsets.symmetric(
          horizontal: tokens.space3,
          vertical: tokens.space2,
        ),
        child: Row(
          children: [
            Icon(icon, color: color, size: tokens.iconMedium),
            SizedBox(width: tokens.space2),
            Expanded(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    displayValue,
                    key: Key('atlas-kpi-value-$label'),
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      color: value == null ? tokens.commandTextMuted : color,
                      fontWeight: FontWeight.w700,
                      fontFeatures: const [FontFeature.tabularFigures()],
                    ),
                  ),
                  Text(
                    label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.labelSmall?.copyWith(
                      color: tokens.commandTextMuted,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class AtlasSectionHeader extends StatelessWidget {
  const AtlasSectionHeader({
    required this.title,
    this.subtitle,
    this.trailing,
    super.key,
  });

  final String title;
  final String? subtitle;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) => Row(
    children: [
      Container(
        width: 3,
        height: 22,
        decoration: BoxDecoration(
          color: context.tokens.commandAccent,
          borderRadius: BorderRadius.circular(2),
        ),
      ),
      SizedBox(width: context.tokens.space2),
      Expanded(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: Theme.of(context).textTheme.titleMedium),
            if (subtitle != null)
              Text(
                subtitle!,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: context.tokens.commandTextMuted,
                ),
              ),
          ],
        ),
      ),
      ?trailing,
    ],
  );
}

/// Preserves Latin identifiers and numbers inside Arabic layouts.
class AtlasIdentifier extends StatelessWidget {
  const AtlasIdentifier(this.value, {this.style, this.maxLines = 1, super.key});

  final String value;
  final TextStyle? style;
  final int maxLines;

  @override
  Widget build(BuildContext context) => Directionality(
    textDirection: TextDirection.ltr,
    child: Text(
      value,
      maxLines: maxLines,
      overflow: TextOverflow.ellipsis,
      textAlign: TextAlign.start,
      style: style,
    ),
  );
}

class AtlasCommandButton extends StatelessWidget {
  const AtlasCommandButton({
    required this.label,
    required this.icon,
    required this.onPressed,
    this.emphasized = false,
    super.key,
  });

  final String label;
  final IconData icon;
  final VoidCallback? onPressed;
  final bool emphasized;

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    final style = ButtonStyle(
      minimumSize: WidgetStatePropertyAll(
        Size(tokens.minimumTouchTarget, tokens.controlHeight),
      ),
      animationDuration: context.motion.effective(context, context.motion.fast),
      side: WidgetStateProperty.resolveWith(
        (states) => BorderSide(
          color: states.contains(WidgetState.focused)
              ? tokens.commandAccent
              : tokens.commandBorder,
          width: states.contains(WidgetState.focused) ? 2 : tokens.borderThin,
        ),
      ),
      shape: WidgetStatePropertyAll(
        RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(tokens.radiusSmall),
        ),
      ),
    );
    return emphasized
        ? FilledButton.icon(
            onPressed: onPressed,
            style: style,
            icon: Icon(icon, size: tokens.iconMedium),
            label: Text(label),
          )
        : OutlinedButton.icon(
            onPressed: onPressed,
            style: style,
            icon: Icon(icon, size: tokens.iconMedium),
            label: Text(label),
          );
  }
}
