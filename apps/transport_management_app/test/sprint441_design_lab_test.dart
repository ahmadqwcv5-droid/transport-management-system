import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:transport_management_app/design_lab/design_lab_app.dart';
import 'package:transport_management_app/design_lab/design_lab_models.dart';

void main() {
  test('query configuration selects explicit concept, surface, and locale', () {
    final configuration = DesignLabConfiguration.fromUri(
      Uri.parse(
        'http://localhost/design-lab?concept=b&surface=truck&locale=en&controls=0',
      ),
    );

    expect(configuration.concept, LabConcept.nightDispatch);
    expect(configuration.surface, LabSurface.driverTruck);
    expect(configuration.locale, const Locale('en'));
    expect(configuration.showControls, isFalse);
  });

  test('Design Lab remains absent from production entry points', () {
    final mainSource = File('lib/main.dart').readAsStringSync();
    final appSource = File('lib/app.dart').readAsStringSync();
    final labSource = Directory('lib/design_lab')
        .listSync()
        .whereType<File>()
        .map((file) => file.readAsStringSync())
        .join('\n');

    expect(mainSource, isNot(contains('design_lab')));
    expect(appSource, isNot(contains('design_lab')));
    expect(labSource, isNot(contains('package:dio')));
    expect(labSource, isNot(contains('Repository')));
    expect(labSource, isNot(contains('/api/')));
  });

  for (final concept in LabConcept.values) {
    for (final locale in const [Locale('ar'), Locale('en')]) {
      for (final width in const [360.0, 768.0, 1440.0]) {
        testWidgets(
          '${concept.name} dashboard renders at ${width.toInt()} ${locale.languageCode}',
          (tester) async {
            await _setSurface(tester, width, width == 1440 ? 900 : 844);
            await tester.pumpWidget(
              DesignLabApp(
                configuration: DesignLabConfiguration(
                  concept: concept,
                  surface: LabSurface.dashboard,
                  locale: locale,
                  showControls: false,
                ),
              ),
            );
            await tester.pump(const Duration(milliseconds: 400));

            expect(
              find.byKey(Key('design-lab-${concept.query}-dashboard')),
              findsOneWidget,
            );
            expect(tester.takeException(), isNull);
            await _resetSurface(tester);
          },
        );
      }
    }

    for (final surface in const [
      LabSurface.driverToday,
      LabSurface.driverTruck,
    ]) {
      testWidgets(
        '${concept.name} ${surface.name} is a distinct 390 RTL surface',
        (tester) async {
          await _setSurface(tester, 390, 844);
          await tester.pumpWidget(
            DesignLabApp(
              configuration: DesignLabConfiguration(
                concept: concept,
                surface: surface,
                locale: const Locale('ar'),
                showControls: false,
              ),
            ),
          );
          await tester.pump(const Duration(milliseconds: 400));

          expect(
            find.byKey(Key('design-lab-${concept.query}-${surface.query}')),
            findsOneWidget,
          );
          expect(
            find.byKey(
              Key(
                surface == LabSurface.driverToday
                    ? 'lab-driver-today'
                    : 'lab-driver-truck',
              ),
            ),
            findsOneWidget,
          );
          expect(tester.takeException(), isNull);
          await _resetSurface(tester);
        },
      );
    }
  }

  testWidgets('component motion sheet settles with reduced motion', (
    tester,
  ) async {
    await _setSurface(tester, 1024, 900);
    final preset = LabConceptPreset.nightDispatch;
    await tester.pumpWidget(
      MaterialApp(
        locale: const Locale('ar'),
        supportedLocales: const [Locale('ar'), Locale('en')],
        localizationsDelegates: GlobalMaterialLocalizations.delegates,
        theme: preset.theme(const Locale('ar')),
        home: MediaQuery(
          data: const MediaQueryData(
            size: Size(1024, 900),
            disableAnimations: true,
          ),
          child: Directionality(
            textDirection: TextDirection.rtl,
            child: Scaffold(body: LabComponentSheet(preset: preset)),
          ),
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 400));

    expect(find.text('لغة الحركة'), findsOneWidget);
    expect(tester.binding.hasScheduledFrame, isFalse);
    expect(tester.takeException(), isNull);
    await _resetSurface(tester);
  });
}

Future<void> _setSurface(
  WidgetTester tester,
  double width,
  double height,
) async {
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = Size(width, height);
}

Future<void> _resetSurface(WidgetTester tester) async {
  tester.view.resetPhysicalSize();
  tester.view.resetDevicePixelRatio();
}
