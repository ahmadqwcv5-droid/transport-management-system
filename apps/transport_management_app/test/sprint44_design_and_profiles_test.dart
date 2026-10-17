import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:transport_management_app/core/config/app_capabilities.dart';
import 'package:transport_management_app/design_system/app_breakpoints.dart';
import 'package:transport_management_app/design_system/app_design_preset.dart';
import 'package:transport_management_app/design_system/app_design_tokens.dart';
import 'package:transport_management_app/design_system/app_motion.dart';
import 'package:transport_management_app/design_system/components/app_metric_card.dart';

void main() {
  test('Pilot and Production cannot expose simulator capability', () {
    for (final profile in ['pilot', 'production', 'unknown']) {
      final capabilities = AppCapabilitySet.resolve(
        profile,
        simulatorRequested: true,
      );
      expect(capabilities.simulatorUi, isFalse);
      expect(capabilities.requiresRealTracking, isTrue);
    }
    expect(
      AppCapabilitySet.resolve(
        'development',
        simulatorRequested: true,
      ).simulatorUi,
      isTrue,
    );
    expect(AppCapabilitySet.resolve('demo').simulatorUi, isFalse);
  });

  testWidgets('alternate injected tokens restyle migrated components', (
    tester,
  ) async {
    const alternateCanvas = Color(0xFFFFF1F2);
    const alternateSurface = Color(0xFFE0F2FE);
    final base = AppDesignTokens.commandCenter();
    final preset = AppDesignPreset(
      name: 'test-preset',
      seedColor: Colors.purple,
      tokens: base.copyWith(
        canvas: alternateCanvas,
        surfaceRaised: alternateSurface,
      ),
    );

    await tester.pumpWidget(
      MaterialApp(
        theme: preset.theme(const Locale('en')),
        home: const Scaffold(
          body: AppMetricCard(
            label: 'Online',
            value: '12',
            icon: Icons.sensors,
          ),
        ),
      ),
    );

    expect(
      tester.widget<Scaffold>(find.byType(Scaffold)).backgroundColor,
      isNull,
    );
    expect(
      Theme.of(tester.element(find.byType(Scaffold))).scaffoldBackgroundColor,
      alternateCanvas,
    );
    expect(
      Theme.of(tester.element(find.byType(Card))).cardTheme.color,
      alternateSurface,
    );
  });

  testWidgets('breakpoints and reduced motion are centralized', (tester) async {
    Future<void> pump(double width, {bool reduceMotion = false}) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: AppDesignPreset.commandCenter().theme(const Locale('en')),
          home: MediaQuery(
            data: MediaQueryData(
              size: Size(width, 800),
              disableAnimations: reduceMotion,
            ),
            child: Builder(
              builder: (context) => Text(
                '${AppBreakpoints.of(context).name}:'
                '${context.motion.effective(context, context.motion.standard).inMilliseconds}',
              ),
            ),
          ),
        ),
      );
    }

    await pump(360);
    expect(find.text('compact:220'), findsOneWidget);
    await pump(768);
    expect(find.text('medium:220'), findsOneWidget);
    await pump(1440);
    expect(find.text('expanded:220'), findsOneWidget);
    await pump(360, reduceMotion: true);
    expect(find.text('compact:0'), findsOneWidget);
  });
}
