import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:transport_management_app/core/maps/locale_aware_map_style.dart';
import 'package:transport_management_app/core/maps/map_camera_movement_classifier.dart';
import 'package:transport_management_app/core/maps/map_interaction_controller.dart';
import 'package:transport_management_app/core/maps/vehicle_motion_interpolator.dart';

void main() {
  group('locale-aware basemap labels', () {
    final source = <String, dynamic>{
      'version': 8,
      'glyphs': 'https://example.test/fonts/{fontstack}/{range}.pbf',
      'sprite': 'https://example.test/sprite',
      'sources': {
        'openmaptiles': {
          'type': 'vector',
          'url': 'https://example.test/tiles.json',
          'attribution': '© OpenStreetMap contributors',
        },
      },
      'layers': [
        {
          'id': 'label_city',
          'type': 'symbol',
          'layout': {
            'text-field': [
              'case',
              ['has', 'name:nonlatin'],
              [
                'concat',
                ['get', 'name:latin'],
                '\n',
                ['get', 'name:nonlatin'],
              ],
              ['get', 'name'],
            ],
            'text-font': ['Noto Sans Regular'],
          },
        },
        {
          'id': 'road-number',
          'type': 'symbol',
          'layout': {
            'text-field': ['get', 'ref'],
          },
        },
      ],
    };

    test('Arabic prefers local script without mixed-direction concat', () {
      final result = LocaleAwareMapStyle.transform(source, 'ar');
      final layout = (result['layers'] as List).first['layout'] as Map;
      expect(layout['text-field'], [
        'coalesce',
        ['get', 'name:ar'],
        ['get', 'name:nonlatin'],
        ['get', 'name'],
        ['get', 'name:latin'],
        ['get', 'name_en'],
      ]);
      expect(jsonEncode(layout['text-field']), isNot(contains('concat')));
      expect(layout['text-font'], ['Noto Sans Regular']);
      expect(result['glyphs'], source['glyphs']);
      expect(result['sprite'], source['sprite']);
      expect(result['sources'], source['sources']);
    });

    test('English prefers Latin and leaves non-name labels untouched', () {
      final result = LocaleAwareMapStyle.transform(source, 'en');
      final layers = result['layers'] as List;
      expect((layers.first['layout'] as Map)['text-field'], [
        'coalesce',
        ['get', 'name:latin'],
        ['get', 'name_en'],
        ['get', 'name'],
        ['get', 'name:nonlatin'],
      ]);
      expect((layers.last['layout'] as Map)['text-field'], ['get', 'ref']);
    });
  });

  group('shared camera semantics', () {
    test('zoom preserves follow while deliberate pan pauses it', () {
      final camera = MapInteractionController(
        initialMode: FleetInteractionMode.followVehicle,
      );
      camera.userZoom();
      expect(camera.mode, FleetInteractionMode.followVehicle);
      camera.userPan();
      expect(camera.mode, FleetInteractionMode.freeExplore);
      camera.followVehicle();
      expect(camera.followsVehicle, isTrue);
      camera.routeOverview();
      expect(camera.mode, FleetInteractionMode.routeOverview);
      camera.fleetOverview();
      expect(camera.mode, FleetInteractionMode.fleetOverview);
    });
  });

  group('embedded map camera event classification', () {
    const initial = MapCameraView(
      latitude: 35,
      longitude: 40,
      zoom: 12,
      bearing: 0,
      tilt: 0,
    );

    test(
      'zoom wins over focal-point movement and preserves follow semantics',
      () {
        final classifier = MapCameraMovementClassifier();
        expect(
          classifier.observe(initial, programmatic: false),
          MapCameraMovement.none,
        );
        expect(
          classifier.observe(
            const MapCameraView(
              latitude: 35.001,
              longitude: 40.001,
              zoom: 12.5,
              bearing: 0,
              tilt: 0,
            ),
            programmatic: false,
          ),
          MapCameraMovement.zoom,
        );
      },
    );

    test('pan is exploration while programmatic movement is ignored', () {
      final classifier = MapCameraMovementClassifier();
      classifier.observe(initial, programmatic: false);
      expect(
        classifier.observe(
          const MapCameraView(
            latitude: 35.01,
            longitude: 40.01,
            zoom: 12,
            bearing: 0,
            tilt: 0,
          ),
          programmatic: false,
        ),
        MapCameraMovement.explore,
      );
      expect(
        classifier.observe(
          const MapCameraView(
            latitude: 36,
            longitude: 41,
            zoom: 13,
            bearing: 10,
            tilt: 20,
          ),
          programmatic: true,
        ),
        MapCameraMovement.none,
      );
    });
  });

  group('latest-wins motion interpolation', () {
    final start = DateTime.utc(2026, 1, 1, 12);
    const origin = VehicleVisualState(latitude: 0, longitude: 0, heading: 359);

    test('uses fake time, bounded duration, and shortest heading arc', () {
      final motion = VehicleMotionInterpolator(
        minimumDuration: const Duration(seconds: 1),
        maximumDuration: const Duration(seconds: 1),
      );
      motion.retarget(target: origin, now: start, animate: false);
      motion.retarget(
        target: const VehicleVisualState(
          latitude: 0.001,
          longitude: 0.001,
          heading: 1,
        ),
        now: start,
      );
      final middle = motion.sample(
        start.add(const Duration(milliseconds: 500)),
      )!;
      expect(middle.latitude, closeTo(0.0005, 0.000001));
      expect(middle.longitude, closeTo(0.0005, 0.000001));
      expect(
        middle.heading == 0 || (middle.heading - 360).abs() < 0.001,
        isTrue,
      );
    });

    test('a newer target cancels from the current visual point', () {
      final motion = VehicleMotionInterpolator(
        minimumDuration: const Duration(seconds: 1),
        maximumDuration: const Duration(seconds: 1),
      );
      motion.retarget(target: origin, now: start, animate: false);
      motion.retarget(
        target: const VehicleVisualState(
          latitude: 0,
          longitude: 0.01,
          heading: 10,
        ),
        now: start,
      );
      final retargetAt = start.add(const Duration(milliseconds: 400));
      final before = motion.sample(retargetAt)!;
      final revision = motion.revision;
      final from = motion.retarget(
        target: const VehicleVisualState(
          latitude: 0,
          longitude: 0.02,
          heading: 20,
        ),
        now: retargetAt,
      );
      expect(motion.revision, revision + 1);
      expect(from.longitude, closeTo(before.longitude, 0.000001));
    });

    test('large reset and offline/stale policy snap immediately', () {
      final motion = VehicleMotionInterpolator(snapDistanceMeters: 1000);
      motion.retarget(target: origin, now: start, animate: false);
      const far = VehicleVisualState(latitude: 10, longitude: 10, heading: 180);
      expect(motion.retarget(target: far, now: start), far);
      const stopped = VehicleVisualState(
        latitude: 10.001,
        longitude: 10,
        heading: 180,
      );
      expect(
        motion.retarget(target: stopped, now: start, animate: false),
        stopped,
      );
      expect(motion.sample(start.add(const Duration(seconds: 1))), stopped);
    });
  });
}
