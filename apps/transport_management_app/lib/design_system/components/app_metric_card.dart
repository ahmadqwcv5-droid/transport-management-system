import 'package:flutter/material.dart';

import '../app_design_tokens.dart';

class AppMetricCard extends StatelessWidget {
  const AppMetricCard({
    required this.label,
    required this.value,
    required this.icon,
    this.accent,
    super.key,
  });

  final String label;
  final String value;
  final IconData icon;
  final Color? accent;

  @override
  Widget build(BuildContext context) {
    final color = accent ?? Theme.of(context).colorScheme.primary;
    return Semantics(
      label: '$label: $value',
      child: Card(
        child: Padding(
          padding: EdgeInsets.all(context.tokens.space4),
          child: Row(
            children: [
              DecoratedBox(
                decoration: BoxDecoration(
                  color: color.withValues(alpha: .1),
                  borderRadius: BorderRadius.circular(
                    context.tokens.radiusSmall,
                  ),
                ),
                child: Padding(
                  padding: EdgeInsets.all(context.tokens.space2),
                  child: Icon(icon, color: color),
                ),
              ),
              SizedBox(width: context.tokens.space3),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(value, style: Theme.of(context).textTheme.titleLarge),
                    Text(
                      label,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: context.tokens.textMuted,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
