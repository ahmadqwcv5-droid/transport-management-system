import 'package:flutter/material.dart';

import '../app_design_tokens.dart';

class AppPageHeader extends StatelessWidget {
  const AppPageHeader({
    required this.title,
    this.subtitle,
    this.leading,
    this.actions = const [],
    super.key,
  });

  final String title;
  final String? subtitle;
  final Widget? leading;
  final List<Widget> actions;

  @override
  Widget build(BuildContext context) => Wrap(
    spacing: context.tokens.space3,
    runSpacing: context.tokens.space2,
    crossAxisAlignment: WrapCrossAlignment.center,
    children: [
      ?leading,
      ConstrainedBox(
        constraints: const BoxConstraints(minWidth: 180, maxWidth: 720),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: Theme.of(context).textTheme.headlineSmall),
            if (subtitle != null)
              Text(
                subtitle!,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: context.tokens.textMuted,
                ),
              ),
          ],
        ),
      ),
      ...actions,
    ],
  );
}
