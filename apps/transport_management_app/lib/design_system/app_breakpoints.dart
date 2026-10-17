import 'package:flutter/widgets.dart';

import 'app_design_tokens.dart';

enum AppWindowClass { compact, medium, expanded }

abstract final class AppBreakpoints {
  static AppWindowClass of(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    final tokens = context.tokens;
    if (width < tokens.compactBreakpoint) return AppWindowClass.compact;
    if (width < tokens.expandedBreakpoint) return AppWindowClass.medium;
    return AppWindowClass.expanded;
  }

  static bool isCompact(BuildContext context) =>
      of(context) == AppWindowClass.compact;

  static bool isExpanded(BuildContext context) =>
      of(context) == AppWindowClass.expanded;
}
