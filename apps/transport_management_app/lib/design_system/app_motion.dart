import 'package:flutter/material.dart';

@immutable
class AppMotionTokens extends ThemeExtension<AppMotionTokens> {
  const AppMotionTokens({
    this.fast = const Duration(milliseconds: 150),
    this.standard = const Duration(milliseconds: 220),
    this.emphasized = const Duration(milliseconds: 300),
  });

  final Duration fast;
  final Duration standard;
  final Duration emphasized;
  Curve get standardCurve => Curves.easeOutCubic;
  Curve get emphasizedCurve => Curves.easeInOutCubic;

  Duration effective(BuildContext context, Duration duration) =>
      MediaQuery.maybeOf(context)?.disableAnimations == true
      ? Duration.zero
      : duration;

  @override
  AppMotionTokens copyWith({
    Duration? fast,
    Duration? standard,
    Duration? emphasized,
  }) => AppMotionTokens(
    fast: fast ?? this.fast,
    standard: standard ?? this.standard,
    emphasized: emphasized ?? this.emphasized,
  );

  @override
  AppMotionTokens lerp(covariant AppMotionTokens? other, double t) =>
      t < .5 ? this : (other ?? this);
}

extension AppMotionContext on BuildContext {
  AppMotionTokens get motion =>
      Theme.of(this).extension<AppMotionTokens>() ?? const AppMotionTokens();
}
