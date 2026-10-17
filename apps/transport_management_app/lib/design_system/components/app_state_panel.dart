import 'package:flutter/material.dart';

import '../app_design_tokens.dart';

enum AppStateKind {
  empty,
  loading,
  error,
  offline,
  stale,
  partial,
  unavailable,
  success,
}

class AppStatePanel extends StatelessWidget {
  const AppStatePanel({
    required this.kind,
    required this.title,
    this.message,
    this.actionLabel,
    this.onAction,
    this.compact = false,
    super.key,
  });

  final AppStateKind kind;
  final String title;
  final String? message;
  final String? actionLabel;
  final VoidCallback? onAction;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final (icon, color) = switch (kind) {
      AppStateKind.error => (Icons.error_outline, context.tokens.danger),
      AppStateKind.offline => (
        Icons.cloud_off_outlined,
        context.tokens.offline,
      ),
      AppStateKind.stale => (Icons.schedule_outlined, context.tokens.stale),
      AppStateKind.partial => (
        Icons.pending_actions_outlined,
        context.tokens.warning,
      ),
      AppStateKind.unavailable => (
        Icons.not_interested_outlined,
        context.tokens.disabled,
      ),
      AppStateKind.success => (
        Icons.check_circle_outline,
        context.tokens.success,
      ),
      AppStateKind.loading => (Icons.hourglass_top, context.tokens.information),
      AppStateKind.empty => (Icons.inbox_outlined, context.tokens.textMuted),
    };
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 520),
        child: Card(
          child: Padding(
            padding: EdgeInsets.all(
              compact ? context.tokens.space4 : context.tokens.space6,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (kind == AppStateKind.loading)
                  CircularProgressIndicator(color: color)
                else
                  Icon(icon, color: color, size: 36),
                SizedBox(height: context.tokens.space3),
                Text(
                  title,
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                if (message != null) ...[
                  SizedBox(height: context.tokens.space2),
                  Text(
                    message!,
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: context.tokens.textMuted,
                    ),
                  ),
                ],
                if (actionLabel != null && onAction != null) ...[
                  SizedBox(height: context.tokens.space4),
                  OutlinedButton(
                    onPressed: onAction,
                    child: Text(actionLabel!),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
