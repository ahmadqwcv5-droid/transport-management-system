import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

import 'design_lab_models.dart';

class DesignLabApp extends StatelessWidget {
  const DesignLabApp({required this.configuration, super.key});

  final DesignLabConfiguration configuration;

  @override
  Widget build(BuildContext context) {
    final preset = LabConceptPreset.of(configuration.concept);
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      locale: configuration.locale,
      supportedLocales: const [Locale('ar'), Locale('en')],
      localizationsDelegates: GlobalMaterialLocalizations.delegates,
      theme: preset.theme(configuration.locale),
      home: DesignLabFrame(configuration: configuration),
    );
  }
}

class DesignLabFrame extends StatefulWidget {
  const DesignLabFrame({required this.configuration, super.key});

  final DesignLabConfiguration configuration;

  @override
  State<DesignLabFrame> createState() => _DesignLabFrameState();
}

class _DesignLabFrameState extends State<DesignLabFrame> {
  late DesignLabConfiguration _configuration = widget.configuration;

  @override
  Widget build(BuildContext context) {
    final preset = LabConceptPreset.of(_configuration.concept);
    final canvas = KeyedSubtree(
      key: Key(
        'design-lab-${_configuration.concept.query}-${_configuration.surface.query}',
      ),
      child: switch (_configuration.surface) {
        LabSurface.dashboard => LabDashboard(preset: preset),
        LabSurface.driverToday => LabDriverToday(preset: preset),
        LabSurface.driverTruck => LabDriverTruck(preset: preset),
        LabSurface.components => LabComponentSheet(preset: preset),
      },
    );
    return Directionality(
      textDirection: _configuration.locale.languageCode == 'ar'
          ? TextDirection.rtl
          : TextDirection.ltr,
      child: Scaffold(
        body: Stack(
          children: [
            Positioned.fill(child: canvas),
            if (_configuration.showControls)
              PositionedDirectional(
                top: 12,
                end: 12,
                child: _DesignLabControls(
                  configuration: _configuration,
                  onChanged: (value) => setState(() => _configuration = value),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _DesignLabControls extends StatelessWidget {
  const _DesignLabControls({
    required this.configuration,
    required this.onChanged,
  });

  final DesignLabConfiguration configuration;
  final ValueChanged<DesignLabConfiguration> onChanged;

  @override
  Widget build(BuildContext context) => Material(
    elevation: 12,
    borderRadius: BorderRadius.circular(14),
    color: Theme.of(context).colorScheme.surface.withValues(alpha: .96),
    child: Padding(
      padding: const EdgeInsets.all(8),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (final concept in LabConcept.values)
            _ControlButton(
              selected: configuration.concept == concept,
              label: concept.query.toUpperCase(),
              onPressed: () =>
                  onChanged(configuration.copyWith(concept: concept)),
            ),
          const SizedBox(width: 6),
          DropdownButton<LabSurface>(
            value: configuration.surface,
            underline: const SizedBox.shrink(),
            items: [
              for (final surface in LabSurface.values)
                DropdownMenuItem(value: surface, child: Text(surface.query)),
            ],
            onChanged: (surface) {
              if (surface != null) {
                onChanged(configuration.copyWith(surface: surface));
              }
            },
          ),
          const SizedBox(width: 6),
          _ControlButton(
            selected: configuration.locale.languageCode == 'ar',
            label: configuration.locale.languageCode == 'ar' ? 'ع' : 'EN',
            onPressed: () => onChanged(
              configuration.copyWith(
                locale: configuration.locale.languageCode == 'ar'
                    ? const Locale('en')
                    : const Locale('ar'),
              ),
            ),
          ),
        ],
      ),
    ),
  );
}

class _ControlButton extends StatelessWidget {
  const _ControlButton({
    required this.selected,
    required this.label,
    required this.onPressed,
  });

  final bool selected;
  final String label;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(horizontal: 2),
    child: TextButton(
      style: TextButton.styleFrom(
        backgroundColor: selected
            ? Theme.of(context).colorScheme.primaryContainer
            : null,
        minimumSize: const Size(42, 42),
      ),
      onPressed: onPressed,
      child: Text(label),
    ),
  );
}

extension _LabCopy on BuildContext {
  bool get ar => Localizations.localeOf(this).languageCode == 'ar';
  String t(String arText, String enText) => ar ? arText : enText;
}

class LabMark extends StatelessWidget {
  const LabMark({required this.preset, this.size = 42, super.key});

  final LabConceptPreset preset;
  final double size;

  @override
  Widget build(BuildContext context) => Semantics(
    label: context.t('علامة المنتج المؤقتة', 'Replaceable product mark'),
    child: SizedBox.square(
      dimension: size,
      child: CustomPaint(painter: _LabMarkPainter(preset)),
    ),
  );
}

class _LabMarkPainter extends CustomPainter {
  const _LabMarkPainter(this.preset);

  final LabConceptPreset preset;

  @override
  void paint(Canvas canvas, Size size) {
    final primary = Paint()
      ..color = preset.primary
      ..style = PaintingStyle.fill;
    final secondary = Paint()
      ..color = preset.secondary
      ..style = PaintingStyle.fill;
    switch (preset.id) {
      case LabConcept.routeBeacon:
        final route = Path()
          ..moveTo(size.width * .18, size.height * .84)
          ..cubicTo(
            size.width * .60,
            size.height * .78,
            size.width * .30,
            size.height * .26,
            size.width * .72,
            size.height * .18,
          )
          ..lineTo(size.width * .84, size.height * .34)
          ..cubicTo(
            size.width * .51,
            size.height * .44,
            size.width * .78,
            size.height * .84,
            size.width * .18,
            size.height * .94,
          )
          ..close();
        canvas.drawPath(route, primary);
        canvas.drawCircle(
          Offset(size.width * .73, size.height * .16),
          size.width * .11,
          secondary,
        );
      case LabConcept.nightDispatch:
        canvas.drawCircle(
          Offset(size.width / 2, size.height / 2),
          size.width * .42,
          Paint()
            ..color = preset.border
            ..style = PaintingStyle.stroke
            ..strokeWidth = size.width * .07,
        );
        canvas.drawArc(
          Rect.fromLTWH(3, 3, size.width - 6, size.height - 6),
          -.6,
          3.7,
          false,
          Paint()
            ..color = preset.primary
            ..style = PaintingStyle.stroke
            ..strokeCap = StrokeCap.round
            ..strokeWidth = size.width * .11,
        );
        canvas.drawCircle(
          Offset(size.width * .69, size.height * .33),
          size.width * .12,
          secondary,
        );
      case LabConcept.fieldLedger:
        final outer = RRect.fromRectAndRadius(
          Rect.fromLTWH(2, 2, size.width - 4, size.height - 4),
          const Radius.circular(2),
        );
        canvas.drawRRect(outer, primary);
        canvas.drawRect(
          Rect.fromLTWH(
            size.width * .22,
            size.height * .18,
            size.width * .12,
            size.height * .64,
          ),
          Paint()..color = preset.surface,
        );
        canvas.drawRect(
          Rect.fromLTWH(
            size.width * .46,
            size.height * .18,
            size.width * .34,
            size.height * .14,
          ),
          secondary,
        );
        canvas.drawRect(
          Rect.fromLTWH(
            size.width * .46,
            size.height * .44,
            size.width * .24,
            size.height * .12,
          ),
          secondary,
        );
    }
  }

  @override
  bool shouldRepaint(covariant _LabMarkPainter oldDelegate) =>
      oldDelegate.preset != preset;
}

class LabStatusPill extends StatelessWidget {
  const LabStatusPill({
    required this.preset,
    required this.label,
    required this.tone,
    this.icon,
    super.key,
  });

  final LabConceptPreset preset;
  final String label;
  final Color tone;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    final square = preset.id == LabConcept.fieldLedger;
    return Container(
      padding: const EdgeInsetsDirectional.fromSTEB(9, 5, 9, 5),
      decoration: BoxDecoration(
        color: tone.withValues(alpha: preset.dark ? .18 : .10),
        border: Border.all(color: tone.withValues(alpha: .65)),
        borderRadius: BorderRadius.circular(square ? 1 : 999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon ?? Icons.circle, size: icon == null ? 8 : 14, color: tone),
          const SizedBox(width: 6),
          Flexible(
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.labelMedium?.copyWith(
                color: preset.ink,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class LabPanel extends StatelessWidget {
  const LabPanel({
    required this.preset,
    required this.child,
    this.padding = const EdgeInsets.all(18),
    this.accent = false,
    super.key,
  });

  final LabConceptPreset preset;
  final Widget child;
  final EdgeInsetsGeometry padding;
  final bool accent;

  @override
  Widget build(BuildContext context) {
    final ledger = preset.id == LabConcept.fieldLedger;
    final night = preset.id == LabConcept.nightDispatch;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: accent ? preset.surfaceStrong : preset.surface,
        border: Border.all(
          color: accent ? preset.primary.withValues(alpha: .7) : preset.border,
          width: night && accent ? 1.5 : 1,
        ),
        borderRadius: BorderRadius.circular(ledger ? 0 : preset.radiusLarge),
        boxShadow: night
            ? null
            : [
                BoxShadow(
                  color: preset.ink.withValues(alpha: .05),
                  blurRadius: 18,
                  offset: const Offset(0, 8),
                ),
              ],
      ),
      child: Padding(padding: padding, child: child),
    );
  }
}

class LabMap extends StatelessWidget {
  const LabMap({required this.preset, this.compact = false, super.key});

  final LabConceptPreset preset;
  final bool compact;

  @override
  Widget build(BuildContext context) => Semantics(
    label: context.t(
      'خريطة أسطول تجريبية ببيانات مصطنعة',
      'Synthetic fleet preview map',
    ),
    child: ClipRRect(
      borderRadius: BorderRadius.circular(
        preset.id == LabConcept.fieldLedger ? 0 : preset.radiusLarge,
      ),
      child: Stack(
        children: [
          Positioned.fill(child: CustomPaint(painter: _LabMapPainter(preset))),
          PositionedDirectional(
            top: 14,
            start: 14,
            child: LabStatusPill(
              preset: preset,
              label: context.t('٤ مركبات مباشرة', '4 live vehicles'),
              tone: preset.success,
              icon: Icons.sensors,
            ),
          ),
          PositionedDirectional(
            top: 14,
            end: 14,
            child: Container(
              decoration: BoxDecoration(
                color: preset.surface.withValues(alpha: .94),
                border: Border.all(color: preset.border),
                borderRadius: BorderRadius.circular(preset.radiusSmall),
              ),
              child: Row(
                children: [
                  _MapButton(
                    icon: Icons.add,
                    label: context.t('تكبير', 'Zoom in'),
                  ),
                  _MapButton(
                    icon: Icons.gps_fixed,
                    label: context.t('توسيط', 'Recenter'),
                  ),
                  if (!compact)
                    _MapButton(
                      icon: Icons.fullscreen,
                      label: context.t('ملء الشاشة', 'Full screen'),
                    ),
                ],
              ),
            ),
          ),
          if (!compact)
            PositionedDirectional(
              bottom: 14,
              end: 14,
              child: Container(
                width: 214,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: preset.surface.withValues(alpha: .96),
                  border: Border.all(color: preset.border),
                  borderRadius: BorderRadius.circular(preset.radiusSmall),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'TRK-204',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      context.t(
                        'وصول متوقع ١٤:٣٢ · ٧٢ كم/س',
                        'ETA 14:32 · 72 km/h',
                      ),
                      style: Theme.of(
                        context,
                      ).textTheme.bodySmall?.copyWith(color: preset.muted),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    ),
  );
}

class _MapButton extends StatelessWidget {
  const _MapButton({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) =>
      IconButton(onPressed: () {}, tooltip: label, icon: Icon(icon, size: 19));
}

class _LabMapPainter extends CustomPainter {
  const _LabMapPainter(this.preset);

  final LabConceptPreset preset;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawRect(Offset.zero & size, Paint()..color = preset.mapLand);
    if (preset.id == LabConcept.nightDispatch) {
      final grid = Paint()
        ..color = preset.border.withValues(alpha: .45)
        ..strokeWidth = 1;
      for (double x = 0; x < size.width; x += 44) {
        canvas.drawLine(Offset(x, 0), Offset(x, size.height), grid);
      }
      for (double y = 0; y < size.height; y += 44) {
        canvas.drawLine(Offset(0, y), Offset(size.width, y), grid);
      }
    }
    final roads = Paint()
      ..color = preset.mapRoad
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeWidth = preset.id == LabConcept.fieldLedger ? 8 : 12;
    final thinRoads = Paint()
      ..color = preset.mapRoad.withValues(alpha: .72)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 4;
    final roadA = Path()
      ..moveTo(-20, size.height * .74)
      ..cubicTo(
        size.width * .22,
        size.height * .56,
        size.width * .44,
        size.height * .82,
        size.width + 20,
        size.height * .35,
      );
    final roadB = Path()
      ..moveTo(size.width * .13, -20)
      ..cubicTo(
        size.width * .20,
        size.height * .35,
        size.width * .72,
        size.height * .40,
        size.width * .82,
        size.height + 20,
      );
    final roadC = Path()
      ..moveTo(size.width * .02, size.height * .28)
      ..quadraticBezierTo(
        size.width * .55,
        size.height * .12,
        size.width * .98,
        size.height * .82,
      );
    canvas.drawPath(roadA, roads);
    canvas.drawPath(roadB, thinRoads);
    canvas.drawPath(roadC, thinRoads);

    final route = Path()
      ..moveTo(size.width * .20, size.height * .66)
      ..cubicTo(
        size.width * .34,
        size.height * .55,
        size.width * .44,
        size.height * .73,
        size.width * .62,
        size.height * .52,
      )
      ..quadraticBezierTo(
        size.width * .73,
        size.height * .39,
        size.width * .79,
        size.height * .24,
      );
    canvas.drawPath(
      route,
      Paint()
        ..color = preset.primary
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round
        ..strokeWidth = 5,
    );
    for (final truck in labTrucks) {
      final center = Offset(size.width * truck.x, size.height * truck.y);
      final tone = truck.online ? preset.success : preset.danger;
      canvas.drawCircle(center, 13, Paint()..color = preset.surface);
      canvas.drawCircle(center, 10, Paint()..color = tone);
      final arrow = Path()
        ..moveTo(center.dx, center.dy - 6)
        ..lineTo(center.dx + 5, center.dy + 5)
        ..lineTo(center.dx - 5, center.dy + 5)
        ..close();
      canvas.drawPath(arrow, Paint()..color = preset.surface);
    }
  }

  @override
  bool shouldRepaint(covariant _LabMapPainter oldDelegate) =>
      oldDelegate.preset != preset;
}

class LabDashboard extends StatelessWidget {
  const LabDashboard({required this.preset, super.key});

  final LabConceptPreset preset;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      if (constraints.maxWidth < 600) {
        return _CompactDashboard(preset: preset);
      }
      return _DashboardShell(
        preset: preset,
        tablet: constraints.maxWidth < 1024,
      );
    },
  );
}

class _DashboardShell extends StatelessWidget {
  const _DashboardShell({required this.preset, required this.tablet});

  final LabConceptPreset preset;
  final bool tablet;

  @override
  Widget build(BuildContext context) {
    final body = switch (preset.id) {
      LabConcept.routeBeacon => _RouteBeaconDashboard(
        preset: preset,
        tablet: tablet,
      ),
      LabConcept.nightDispatch => _NightDispatchDashboard(
        preset: preset,
        tablet: tablet,
      ),
      LabConcept.fieldLedger => _FieldLedgerDashboard(
        preset: preset,
        tablet: tablet,
      ),
    };
    return SafeArea(
      child: tablet
          ? Column(
              children: [
                _TabletNavigation(preset: preset),
                Expanded(child: body),
              ],
            )
          : Row(
              children: [
                _ConceptNavigation(preset: preset),
                Expanded(child: body),
              ],
            ),
    );
  }
}

class _ConceptNavigation extends StatelessWidget {
  const _ConceptNavigation({required this.preset});

  final LabConceptPreset preset;

  @override
  Widget build(BuildContext context) {
    final expanded = preset.id == LabConcept.fieldLedger;
    return Container(
      width: preset.navigationWidth,
      decoration: BoxDecoration(
        color: preset.id == LabConcept.routeBeacon
            ? preset.ink
            : preset.surface,
        border: BorderDirectional(end: BorderSide(color: preset.border)),
      ),
      child: Column(
        crossAxisAlignment: expanded
            ? CrossAxisAlignment.start
            : CrossAxisAlignment.center,
        children: [
          Padding(
            padding: EdgeInsetsDirectional.fromSTEB(
              expanded ? 22 : 0,
              24,
              expanded ? 22 : 0,
              30,
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                LabMark(preset: preset, size: 40),
                if (expanded) ...[
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          context.t('مدار', 'Madar'),
                          style: Theme.of(context).textTheme.titleLarge
                              ?.copyWith(fontWeight: FontWeight.w700),
                        ),
                        Text(
                          context.t('سجل العمليات', 'Operations ledger'),
                          style: Theme.of(
                            context,
                          ).textTheme.labelSmall?.copyWith(color: preset.muted),
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),
          for (var index = 0; index < _navigationItems.length; index++)
            _NavigationItem(
              preset: preset,
              item: _navigationItems[index],
              selected: index == 0,
              expanded: expanded,
              index: index + 1,
            ),
          const Spacer(),
          if (expanded)
            Padding(
              padding: const EdgeInsets.all(20),
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 18,
                    backgroundColor: preset.primary,
                    foregroundColor: _readableForeground(preset.primary),
                    child: const Text('م'),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(context.t('مشرف العمليات', 'Operations lead')),
                        Text(
                          context.t('شركة تجريبية', 'Demo company'),
                          style: Theme.of(
                            context,
                          ).textTheme.labelSmall?.copyWith(color: preset.muted),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            )
          else ...[
            IconButton(
              onPressed: () {},
              tooltip: context.t('الإشعارات', 'Notifications'),
              icon: const Icon(Icons.notifications_none_rounded),
            ),
            const SizedBox(height: 12),
            CircleAvatar(
              radius: 20,
              backgroundColor: preset.primary,
              foregroundColor: _readableForeground(preset.primary),
              child: const Text('م'),
            ),
            const SizedBox(height: 20),
          ],
        ],
      ),
    );
  }
}

const _navigationItems = [
  (Icons.space_dashboard_outlined, 'لوحة التشغيل', 'Command'),
  (Icons.route_outlined, 'الرحلات', 'Trips'),
  (Icons.local_shipping_outlined, 'الأسطول', 'Fleet'),
  (Icons.people_outline_rounded, 'الفريق', 'People'),
  (Icons.tune_rounded, 'الإعدادات', 'Settings'),
];

class _NavigationItem extends StatelessWidget {
  const _NavigationItem({
    required this.preset,
    required this.item,
    required this.selected,
    required this.expanded,
    required this.index,
  });

  final LabConceptPreset preset;
  final (IconData, String, String) item;
  final bool selected;
  final bool expanded;
  final int index;

  @override
  Widget build(BuildContext context) {
    final routeBeacon = preset.id == LabConcept.routeBeacon;
    final content = expanded
        ? Row(
            children: [
              SizedBox(
                width: 24,
                child: Text(
                  '$index'.padLeft(2, '0'),
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    color: selected ? preset.primary : preset.muted,
                  ),
                ),
              ),
              Icon(item.$1, size: 20),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  context.t(item.$2, item.$3),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          )
        : Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(item.$1, size: 22),
              const SizedBox(height: 5),
              Text(
                context.t(item.$2, item.$3),
                maxLines: 1,
                style: Theme.of(context).textTheme.labelSmall,
              ),
            ],
          );
    return Padding(
      padding: EdgeInsetsDirectional.fromSTEB(
        expanded ? 14 : 9,
        3,
        expanded ? 14 : 9,
        3,
      ),
      child: Material(
        color: selected
            ? (routeBeacon
                  ? preset.primary
                  : preset.primary.withValues(alpha: .14))
            : Colors.transparent,
        borderRadius: BorderRadius.circular(expanded ? 0 : preset.radiusSmall),
        child: InkWell(
          onTap: () {},
          borderRadius: BorderRadius.circular(preset.radiusSmall),
          child: Container(
            height: expanded ? 48 : 62,
            alignment: Alignment.center,
            padding: EdgeInsets.symmetric(horizontal: expanded ? 12 : 4),
            decoration: expanded && selected
                ? BoxDecoration(
                    border: BorderDirectional(
                      start: BorderSide(color: preset.primary, width: 3),
                    ),
                  )
                : null,
            child: IconTheme(
              data: IconThemeData(
                color: selected
                    ? (routeBeacon ? Colors.white : preset.primary)
                    : (routeBeacon ? Colors.white70 : preset.muted),
              ),
              child: DefaultTextStyle.merge(
                style: TextStyle(
                  color: selected
                      ? (routeBeacon ? Colors.white : preset.ink)
                      : (routeBeacon ? Colors.white70 : preset.muted),
                  fontWeight: selected ? FontWeight.w700 : FontWeight.w400,
                ),
                child: content,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _TabletNavigation extends StatelessWidget {
  const _TabletNavigation({required this.preset});

  final LabConceptPreset preset;

  @override
  Widget build(BuildContext context) => Container(
    height: 68,
    padding: const EdgeInsets.symmetric(horizontal: 18),
    decoration: BoxDecoration(
      color: preset.surface,
      border: Border(bottom: BorderSide(color: preset.border)),
    ),
    child: Row(
      children: [
        LabMark(preset: preset, size: 36),
        const SizedBox(width: 12),
        Text(
          preset.name(Localizations.localeOf(context)),
          style: Theme.of(
            context,
          ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
        ),
        const Spacer(),
        for (final item in _navigationItems.take(4))
          IconButton(
            onPressed: () {},
            tooltip: context.t(item.$2, item.$3),
            icon: Icon(item.$1),
          ),
      ],
    ),
  );
}

class _DashboardHeading extends StatelessWidget {
  const _DashboardHeading({required this.preset, this.eyebrow});

  final LabConceptPreset preset;
  final String? eyebrow;

  @override
  Widget build(BuildContext context) => Row(
    crossAxisAlignment: CrossAxisAlignment.center,
    children: [
      Expanded(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              eyebrow ??
                  context.t('السبت · ١٧ أكتوبر', 'Saturday · 17 October'),
              style: Theme.of(context).textTheme.labelMedium?.copyWith(
                color: preset.primary,
                fontWeight: FontWeight.w700,
                letterSpacing: context.ar ? 0 : 1.1,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              context.t('نبض الأسطول الآن', 'Fleet pulse, right now'),
              style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                fontWeight: FontWeight.w700,
                letterSpacing: context.ar ? 0 : -.8,
              ),
            ),
          ],
        ),
      ),
      LabStatusPill(
        preset: preset,
        label: context.t('تحديث قبل ١٨ ثانية', 'Updated 18 sec ago'),
        tone: preset.success,
        icon: Icons.sync_rounded,
      ),
      const SizedBox(width: 10),
      IconButton(
        onPressed: () {},
        tooltip: context.t('الإشعارات', 'Notifications'),
        icon: const Badge(
          label: Text('3'),
          child: Icon(Icons.notifications_none_rounded),
        ),
      ),
    ],
  );
}

class _PrimaryMetric extends StatelessWidget {
  const _PrimaryMetric({
    required this.preset,
    required this.value,
    required this.labelAr,
    required this.labelEn,
    required this.icon,
    this.signal,
  });

  final LabConceptPreset preset;
  final String value;
  final String labelAr;
  final String labelEn;
  final IconData icon;
  final Color? signal;

  @override
  Widget build(BuildContext context) {
    final ledger = preset.id == LabConcept.fieldLedger;
    final night = preset.id == LabConcept.nightDispatch;
    return Expanded(
      child: Container(
        constraints: const BoxConstraints(minWidth: 118),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
        decoration: BoxDecoration(
          color: night ? preset.surface.withValues(alpha: .94) : preset.surface,
          border: Border.all(color: preset.border),
          borderRadius: BorderRadius.circular(ledger ? 0 : preset.radiusSmall),
        ),
        child: Row(
          children: [
            Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                color: (signal ?? preset.primary).withValues(alpha: .13),
                shape: ledger ? BoxShape.rectangle : BoxShape.circle,
              ),
              child: Icon(icon, color: signal ?? preset.primary, size: 20),
            ),
            const SizedBox(width: 11),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    value,
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      height: 1,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    context.t(labelAr, labelEn),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(
                      context,
                    ).textTheme.labelMedium?.copyWith(color: preset.muted),
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

class _MetricStrip extends StatelessWidget {
  const _MetricStrip({required this.preset});

  final LabConceptPreset preset;

  @override
  Widget build(BuildContext context) => Row(
    children: [
      _PrimaryMetric(
        preset: preset,
        value: '24',
        labelAr: 'مركبة نشطة',
        labelEn: 'Active vehicles',
        icon: Icons.local_shipping_outlined,
      ),
      const SizedBox(width: 10),
      _PrimaryMetric(
        preset: preset,
        value: '07',
        labelAr: 'رحلات جارية',
        labelEn: 'Trips underway',
        icon: Icons.route_outlined,
        signal: preset.secondary,
      ),
      const SizedBox(width: 10),
      _PrimaryMetric(
        preset: preset,
        value: '11',
        labelAr: 'متاحة الآن',
        labelEn: 'Available now',
        icon: Icons.task_alt_rounded,
        signal: preset.success,
      ),
      const SizedBox(width: 10),
      _PrimaryMetric(
        preset: preset,
        value: '03',
        labelAr: 'تحتاج متابعة',
        labelEn: 'Need attention',
        icon: Icons.priority_high_rounded,
        signal: preset.signal,
      ),
    ],
  );
}

class _FleetList extends StatelessWidget {
  const _FleetList({required this.preset, this.compact = false});

  final LabConceptPreset preset;
  final bool compact;

  @override
  Widget build(BuildContext context) => LabPanel(
    preset: preset,
    padding: EdgeInsets.all(compact ? 12 : 16),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                context.t('الأسطول المباشر', 'Live fleet'),
                style: Theme.of(
                  context,
                ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
              ),
            ),
            Icon(Icons.tune_rounded, size: 19, color: preset.muted),
          ],
        ),
        const SizedBox(height: 12),
        for (var index = 0; index < labTrucks.length; index++) ...[
          _TruckRow(
            preset: preset,
            truck: labTrucks[index],
            selected: index == 0,
          ),
          if (index != labTrucks.length - 1)
            Divider(height: 12, color: preset.border),
        ],
        if (!compact) ...[
          const Spacer(),
          OutlinedButton.icon(
            onPressed: () {},
            icon: const Icon(Icons.view_list_outlined, size: 18),
            label: Text(context.t('عرض الأسطول كاملاً', 'View full fleet')),
          ),
        ],
      ],
    ),
  );
}

class _TruckRow extends StatelessWidget {
  const _TruckRow({
    required this.preset,
    required this.truck,
    required this.selected,
  });

  final LabConceptPreset preset;
  final LabTruck truck;
  final bool selected;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 8),
    decoration: BoxDecoration(
      color: selected ? preset.primary.withValues(alpha: .11) : null,
      borderRadius: BorderRadius.circular(preset.radiusSmall),
      border: selected && preset.id == LabConcept.nightDispatch
          ? Border.all(color: preset.primary.withValues(alpha: .6))
          : null,
    ),
    child: Row(
      children: [
        Container(
          width: 34,
          height: 34,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: truck.online
                ? preset.success.withValues(alpha: .12)
                : preset.danger.withValues(alpha: .12),
            borderRadius: BorderRadius.circular(preset.radiusSmall),
          ),
          child: Icon(
            Icons.local_shipping_rounded,
            size: 18,
            color: truck.online ? preset.success : preset.danger,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                truck.code,
                style: const TextStyle(fontWeight: FontWeight.w700),
              ),
              Text(
                context.ar ? truck.status : _statusEn(truck.status),
                style: Theme.of(
                  context,
                ).textTheme.labelSmall?.copyWith(color: preset.muted),
              ),
            ],
          ),
        ),
        Text(
          truck.speed == 0 ? '—' : '${truck.speed}',
          style: Theme.of(context).textTheme.labelLarge?.copyWith(
            color: selected ? preset.primary : preset.muted,
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    ),
  );
}

String _statusEn(String status) => switch (status) {
  'في الطريق' => 'In transit',
  'عند الاستلام' => 'At pickup',
  'متاحة' => 'Available',
  _ => 'Needs attention',
};

class _RouteBeaconDashboard extends StatelessWidget {
  const _RouteBeaconDashboard({required this.preset, required this.tablet});

  final LabConceptPreset preset;
  final bool tablet;

  @override
  Widget build(BuildContext context) => Container(
    color: preset.canvas,
    padding: EdgeInsets.all(tablet ? 18 : 26),
    child: Column(
      children: [
        _DashboardHeading(preset: preset),
        const SizedBox(height: 18),
        _MetricStrip(preset: preset),
        const SizedBox(height: 18),
        Expanded(
          child: Row(
            children: [
              Expanded(
                flex: tablet ? 7 : 8,
                child: LabPanel(
                  preset: preset,
                  padding: EdgeInsets.zero,
                  child: LabMap(preset: preset),
                ),
              ),
              const SizedBox(width: 16),
              SizedBox(
                width: tablet ? 220 : 276,
                child: _FleetList(preset: preset, compact: tablet),
              ),
            ],
          ),
        ),
      ],
    ),
  );
}

class _NightDispatchDashboard extends StatelessWidget {
  const _NightDispatchDashboard({required this.preset, required this.tablet});

  final LabConceptPreset preset;
  final bool tablet;

  @override
  Widget build(BuildContext context) {
    if (tablet) {
      return _RouteBeaconDashboard(preset: preset, tablet: true);
    }
    return Container(
      color: preset.canvas,
      padding: const EdgeInsets.all(18),
      child: Stack(
        children: [
          Positioned.fill(child: LabMap(preset: preset)),
          PositionedDirectional(
            top: 16,
            start: 18,
            end: 18,
            child: Column(
              children: [
                LabPanel(
                  preset: preset,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 18,
                    vertical: 12,
                  ),
                  child: _DashboardHeading(
                    preset: preset,
                    eyebrow: context.t(
                      'مركز المتابعة · مباشر',
                      'LIVE CONTROL · DISPATCH',
                    ),
                  ),
                ),
                const SizedBox(height: 10),
                _MetricStrip(preset: preset),
              ],
            ),
          ),
          PositionedDirectional(
            top: 190,
            bottom: 18,
            start: 18,
            width: 260,
            child: _FleetList(preset: preset),
          ),
          PositionedDirectional(
            bottom: 18,
            end: 18,
            width: 280,
            child: LabPanel(
              preset: preset,
              accent: true,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    context.t('تنبيه تشغيلي', 'Operational signal'),
                    style: Theme.of(context).textTheme.labelMedium?.copyWith(
                      color: preset.signal,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    context.t(
                      'TRK-330 لم ترسل موقعاً منذ ١٢ دقيقة',
                      'TRK-330 has not reported for 12 minutes',
                    ),
                    style: Theme.of(context).textTheme.titleSmall,
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _FieldLedgerDashboard extends StatelessWidget {
  const _FieldLedgerDashboard({required this.preset, required this.tablet});

  final LabConceptPreset preset;
  final bool tablet;

  @override
  Widget build(BuildContext context) => Container(
    color: preset.canvas,
    padding: EdgeInsets.fromLTRB(tablet ? 18 : 30, 22, tablet ? 18 : 30, 22),
    child: Column(
      children: [
        _DashboardHeading(preset: preset),
        const SizedBox(height: 14),
        _MetricStrip(preset: preset),
        const SizedBox(height: 14),
        Expanded(
          child: Row(
            children: [
              Expanded(
                flex: 7,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          context.t('خريطة الحركة / ٠١', 'MOVEMENT MAP / 01'),
                          style: Theme.of(context).textTheme.labelMedium
                              ?.copyWith(
                                letterSpacing: context.ar ? 0 : 1.2,
                                fontWeight: FontWeight.w700,
                              ),
                        ),
                        const Spacer(),
                        Text(
                          context.t('المنطقة التجريبية', 'SYNTHETIC REGION'),
                          style: Theme.of(
                            context,
                          ).textTheme.labelSmall?.copyWith(color: preset.muted),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Expanded(child: LabMap(preset: preset)),
                  ],
                ),
              ),
              const SizedBox(width: 18),
              SizedBox(
                width: tablet ? 230 : 302,
                child: _LedgerManifest(preset: preset),
              ),
            ],
          ),
        ),
      ],
    ),
  );
}

class _LedgerManifest extends StatelessWidget {
  const _LedgerManifest({required this.preset});

  final LabConceptPreset preset;

  @override
  Widget build(BuildContext context) => LabPanel(
    preset: preset,
    padding: EdgeInsets.zero,
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          padding: const EdgeInsets.all(16),
          color: preset.primary,
          child: Text(
            context.t('سجل التحركات', 'MOVEMENT LEDGER'),
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
              color: Colors.white,
              fontWeight: FontWeight.w700,
              letterSpacing: context.ar ? 0 : 1,
            ),
          ),
        ),
        Expanded(
          child: ListView.separated(
            padding: EdgeInsets.zero,
            itemCount: labTrucks.length,
            separatorBuilder: (_, _) =>
                Divider(height: 1, color: preset.border),
            itemBuilder: (context, index) {
              final truck = labTrucks[index];
              return Padding(
                padding: const EdgeInsets.all(14),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${index + 1}'.padLeft(2, '0'),
                      style: Theme.of(context).textTheme.labelSmall?.copyWith(
                        color: preset.primary,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            truck.code,
                            style: const TextStyle(fontWeight: FontWeight.w700),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            context.ar ? truck.status : _statusEn(truck.status),
                            style: Theme.of(context).textTheme.bodySmall
                                ?.copyWith(color: preset.muted),
                          ),
                          const SizedBox(height: 8),
                          LinearProgressIndicator(
                            value: index == 0 ? .68 : .30 + index * .12,
                            minHeight: 3,
                            backgroundColor: preset.surfaceStrong,
                            color: truck.online
                                ? preset.primary
                                : preset.danger,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        ),
      ],
    ),
  );
}

class _CompactDashboard extends StatelessWidget {
  const _CompactDashboard({required this.preset});

  final LabConceptPreset preset;

  @override
  Widget build(BuildContext context) => SafeArea(
    child: Column(
      children: [
        _MobileTopBar(
          preset: preset,
          title: context.t('مركز الأسطول', 'Fleet center'),
        ),
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(14, 14, 14, 20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  context.t('نبض الأسطول الآن', 'Fleet pulse, right now'),
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 14),
                GridView.count(
                  crossAxisCount: 2,
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  childAspectRatio: 1.5,
                  mainAxisSpacing: 8,
                  crossAxisSpacing: 8,
                  children: [
                    _CompactMetric(
                      preset: preset,
                      value: '24',
                      label: context.t('نشطة', 'Active'),
                    ),
                    _CompactMetric(
                      preset: preset,
                      value: '07',
                      label: context.t('رحلات', 'Trips'),
                    ),
                    _CompactMetric(
                      preset: preset,
                      value: '11',
                      label: context.t('متاحة', 'Available'),
                    ),
                    _CompactMetric(
                      preset: preset,
                      value: '03',
                      label: context.t('انتباه', 'Attention'),
                      tone: preset.signal,
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                SizedBox(
                  height: 430,
                  child: LabMap(preset: preset, compact: true),
                ),
                const SizedBox(height: 12),
                SizedBox(
                  height: 330,
                  child: _FleetList(preset: preset, compact: true),
                ),
              ],
            ),
          ),
        ),
        _MobileNavigation(preset: preset, selected: 0),
      ],
    ),
  );
}

class _CompactMetric extends StatelessWidget {
  const _CompactMetric({
    required this.preset,
    required this.value,
    required this.label,
    this.tone,
  });

  final LabConceptPreset preset;
  final String value;
  final String label;
  final Color? tone;

  @override
  Widget build(BuildContext context) => LabPanel(
    preset: preset,
    padding: const EdgeInsets.all(12),
    child: Row(
      children: [
        Container(width: 4, height: 36, color: tone ?? preset.primary),
        const SizedBox(width: 10),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              value,
              style: Theme.of(
                context,
              ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700),
            ),
            Text(
              label,
              style: Theme.of(
                context,
              ).textTheme.labelSmall?.copyWith(color: preset.muted),
            ),
          ],
        ),
      ],
    ),
  );
}

class _MobileTopBar extends StatelessWidget {
  const _MobileTopBar({required this.preset, required this.title});

  final LabConceptPreset preset;
  final String title;

  @override
  Widget build(BuildContext context) => Container(
    height: 68,
    padding: const EdgeInsets.symmetric(horizontal: 16),
    decoration: BoxDecoration(
      color: preset.surface,
      border: Border(bottom: BorderSide(color: preset.border)),
    ),
    child: Row(
      children: [
        LabMark(preset: preset, size: 36),
        const SizedBox(width: 11),
        Expanded(
          child: Text(
            title,
            style: Theme.of(
              context,
            ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
          ),
        ),
        IconButton(
          onPressed: () {},
          tooltip: context.t('الإشعارات', 'Notifications'),
          icon: const Badge(
            label: Text('3'),
            child: Icon(Icons.notifications_none_rounded),
          ),
        ),
      ],
    ),
  );
}

class _MobileNavigation extends StatelessWidget {
  const _MobileNavigation({required this.preset, required this.selected});

  final LabConceptPreset preset;
  final int selected;

  @override
  Widget build(BuildContext context) {
    final items = [
      (Icons.today_outlined, 'اليوم', 'Today'),
      (Icons.local_shipping_outlined, 'شاحنتي', 'My truck'),
      (Icons.history_rounded, 'رحلاتي', 'My trips'),
      (Icons.person_outline_rounded, 'حسابي', 'Profile'),
    ];
    return Container(
      height: 76,
      padding: const EdgeInsets.only(bottom: 4),
      decoration: BoxDecoration(
        color: preset.surface,
        border: Border(top: BorderSide(color: preset.border)),
      ),
      child: Row(
        children: [
          for (var index = 0; index < items.length; index++)
            Expanded(
              child: InkWell(
                onTap: () {},
                child: Container(
                  margin: const EdgeInsets.symmetric(
                    horizontal: 4,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: index == selected
                        ? preset.primary.withValues(alpha: .13)
                        : null,
                    border:
                        preset.id == LabConcept.fieldLedger && index == selected
                        ? Border(
                            top: BorderSide(color: preset.primary, width: 2),
                          )
                        : null,
                    borderRadius: BorderRadius.circular(
                      preset.id == LabConcept.fieldLedger
                          ? 0
                          : preset.radiusSmall,
                    ),
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        items[index].$1,
                        size: 21,
                        color: index == selected
                            ? preset.primary
                            : preset.muted,
                      ),
                      const SizedBox(height: 3),
                      Text(
                        context.t(items[index].$2, items[index].$3),
                        style: Theme.of(context).textTheme.labelSmall?.copyWith(
                          color: index == selected
                              ? preset.primary
                              : preset.muted,
                          fontWeight: index == selected
                              ? FontWeight.w700
                              : FontWeight.w400,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class LabDriverToday extends StatelessWidget {
  const LabDriverToday({required this.preset, super.key});

  final LabConceptPreset preset;

  @override
  Widget build(BuildContext context) => _DriverFrame(
    key: const Key('lab-driver-today'),
    preset: preset,
    title: context.t('اليوم', 'Today'),
    selectedNavigation: 0,
    child: switch (preset.id) {
      LabConcept.routeBeacon => _RouteBeaconToday(preset: preset),
      LabConcept.nightDispatch => _NightDispatchToday(preset: preset),
      LabConcept.fieldLedger => _FieldLedgerToday(preset: preset),
    },
  );
}

class LabDriverTruck extends StatelessWidget {
  const LabDriverTruck({required this.preset, super.key});

  final LabConceptPreset preset;

  @override
  Widget build(BuildContext context) => _DriverFrame(
    key: const Key('lab-driver-truck'),
    preset: preset,
    title: context.t('شاحنتي', 'My truck'),
    selectedNavigation: 1,
    child: switch (preset.id) {
      LabConcept.routeBeacon => _RouteBeaconTruck(preset: preset),
      LabConcept.nightDispatch => _NightDispatchTruck(preset: preset),
      LabConcept.fieldLedger => _FieldLedgerTruck(preset: preset),
    },
  );
}

class _DriverFrame extends StatelessWidget {
  const _DriverFrame({
    required this.preset,
    required this.title,
    required this.selectedNavigation,
    required this.child,
    super.key,
  });

  final LabConceptPreset preset;
  final String title;
  final int selectedNavigation;
  final Widget child;

  @override
  Widget build(BuildContext context) => SafeArea(
    child: Column(
      children: [
        _MobileTopBar(preset: preset, title: title),
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(14, 14, 14, 22),
            child: child,
          ),
        ),
        _MobileNavigation(preset: preset, selected: selectedNavigation),
      ],
    ),
  );
}

class _DriverIdentity extends StatelessWidget {
  const _DriverIdentity({required this.preset});

  final LabConceptPreset preset;

  @override
  Widget build(BuildContext context) => Row(
    children: [
      CircleAvatar(
        radius: 22,
        backgroundColor: preset.primary,
        foregroundColor: _readableForeground(preset.primary),
        child: const Text('س١'),
      ),
      const SizedBox(width: 11),
      Expanded(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              context.t('مرحباً، سائق ٠١', 'Hello, Driver 01'),
              style: Theme.of(
                context,
              ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
            ),
            Text(
              context.t('شركة المسار التجريبية', 'Madar Demo Logistics'),
              style: Theme.of(
                context,
              ).textTheme.bodySmall?.copyWith(color: preset.muted),
            ),
          ],
        ),
      ),
      LabStatusPill(
        preset: preset,
        label: context.t('متصل', 'Online'),
        tone: preset.success,
      ),
    ],
  );
}

class _RouteBeaconToday extends StatelessWidget {
  const _RouteBeaconToday({required this.preset});

  final LabConceptPreset preset;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      _DriverIdentity(preset: preset),
      const SizedBox(height: 16),
      LabPanel(
        preset: preset,
        accent: true,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            LabStatusPill(
              preset: preset,
              label: context.t('الرحلة الحالية', 'Current trip'),
              tone: preset.secondary,
              icon: Icons.route_outlined,
            ),
            const SizedBox(height: 14),
            Text(
              'TRP-842',
              style: Theme.of(
                context,
              ).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 16),
            _RouteStop(
              preset: preset,
              active: false,
              title: context.t('مستودع الشمال', 'North depot'),
              subtitle: context.t('تم الاستلام · ١٢:٤٠', 'Picked up · 12:40'),
            ),
            _RouteSpine(preset: preset),
            _RouteStop(
              preset: preset,
              active: true,
              title: context.t('بوابة التوزيع', 'Distribution gate'),
              subtitle: context.t(
                'الوصول المتوقع · ١٤:٣٢',
                'Expected arrival · 14:32',
              ),
            ),
            const SizedBox(height: 18),
            LinearProgressIndicator(
              value: .68,
              minHeight: 7,
              borderRadius: BorderRadius.circular(8),
              backgroundColor: preset.surfaceStrong,
              color: preset.primary,
            ),
            const SizedBox(height: 9),
            Row(
              children: [
                Text(context.t('متبقٍ ٤٢ كم', '42 km remaining')),
                const Spacer(),
                Text(
                  '68%',
                  style: TextStyle(
                    color: preset.primary,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
      const SizedBox(height: 12),
      _NextActionPanel(preset: preset),
      const SizedBox(height: 12),
      _TruckMiniSummary(preset: preset),
    ],
  );
}

class _RouteStop extends StatelessWidget {
  const _RouteStop({
    required this.preset,
    required this.active,
    required this.title,
    required this.subtitle,
  });

  final LabConceptPreset preset;
  final bool active;
  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) => Row(
    children: [
      Container(
        width: 22,
        height: 22,
        decoration: BoxDecoration(
          color: active ? preset.primary : preset.success,
          shape: BoxShape.circle,
          border: Border.all(color: preset.surface, width: 4),
          boxShadow: [
            BoxShadow(
              color: (active ? preset.primary : preset.success).withValues(
                alpha: .22,
              ),
              blurRadius: 0,
              spreadRadius: 4,
            ),
          ],
        ),
      ),
      const SizedBox(width: 12),
      Expanded(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: const TextStyle(fontWeight: FontWeight.w700)),
            Text(
              subtitle,
              style: Theme.of(
                context,
              ).textTheme.bodySmall?.copyWith(color: preset.muted),
            ),
          ],
        ),
      ),
    ],
  );
}

class _RouteSpine extends StatelessWidget {
  const _RouteSpine({required this.preset});

  final LabConceptPreset preset;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsetsDirectional.only(start: 10),
    child: Container(
      width: 2,
      height: 38,
      color: preset.primary.withValues(alpha: .45),
    ),
  );
}

class _NextActionPanel extends StatelessWidget {
  const _NextActionPanel({required this.preset});

  final LabConceptPreset preset;

  @override
  Widget build(BuildContext context) => LabPanel(
    preset: preset,
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          context.t('خطوتك التالية', 'Your next action'),
          style: Theme.of(context).textTheme.labelLarge?.copyWith(
            color: preset.primary,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          context.t(
            'تابع نحو بوابة التوزيع ثم أكّد الوصول.',
            'Continue to the distribution gate, then confirm arrival.',
          ),
          style: Theme.of(context).textTheme.titleMedium,
        ),
        const SizedBox(height: 14),
        SizedBox(
          width: double.infinity,
          child: FilledButton.icon(
            onPressed: () {},
            icon: const Icon(Icons.near_me_outlined),
            label: Text(context.t('فتح التوجيه', 'Open guidance')),
          ),
        ),
      ],
    ),
  );
}

class _NightDispatchToday extends StatelessWidget {
  const _NightDispatchToday({required this.preset});

  final LabConceptPreset preset;

  @override
  Widget build(BuildContext context) => Column(
    children: [
      _DriverIdentity(preset: preset),
      const SizedBox(height: 14),
      LabPanel(
        preset: preset,
        accent: true,
        child: Row(
          children: [
            SizedBox.square(
              dimension: 116,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  CircularProgressIndicator(
                    value: .68,
                    strokeWidth: 10,
                    backgroundColor: preset.border,
                    color: preset.primary,
                  ),
                  Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        '68%',
                        style: Theme.of(context).textTheme.headlineSmall
                            ?.copyWith(fontWeight: FontWeight.w700),
                      ),
                      Text(
                        context.t('مكتمل', 'complete'),
                        style: Theme.of(
                          context,
                        ).textTheme.labelSmall?.copyWith(color: preset.muted),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(width: 18),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'TRP-842',
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 5),
                  Text(
                    context.t('إلى بوابة التوزيع', 'To distribution gate'),
                    style: TextStyle(color: preset.muted),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Icon(Icons.schedule, size: 17, color: preset.signal),
                      const SizedBox(width: 6),
                      Text(context.t('وصول ١٤:٣٢', 'ETA 14:32')),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
      const SizedBox(height: 12),
      SizedBox(height: 255, child: LabMap(preset: preset, compact: true)),
      const SizedBox(height: 12),
      LabPanel(
        preset: preset,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              context.t('الإجراء الحالي', 'CURRENT ACTION'),
              style: Theme.of(context).textTheme.labelMedium?.copyWith(
                color: preset.primary,
                fontWeight: FontWeight.w700,
                letterSpacing: context.ar ? 0 : 1.2,
              ),
            ),
            const SizedBox(height: 7),
            Text(
              context.t(
                'استمر في المسار. سننبهك عند الاقتراب.',
                'Stay on route. We will alert you on approach.',
              ),
              style: Theme.of(context).textTheme.titleMedium,
            ),
          ],
        ),
      ),
      const SizedBox(height: 12),
      _TruckMiniSummary(preset: preset),
    ],
  );
}

class _FieldLedgerToday extends StatelessWidget {
  const _FieldLedgerToday({required this.preset});

  final LabConceptPreset preset;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      _DriverIdentity(preset: preset),
      const SizedBox(height: 14),
      Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 8),
        decoration: BoxDecoration(
          border: Border(
            top: BorderSide(color: preset.ink, width: 2),
            bottom: BorderSide(color: preset.border),
          ),
        ),
        child: Text(
          context.t('أمر العمل · ١٧ أكتوبر · ٠١', 'WORK ORDER · 17 OCT · 01'),
          style: Theme.of(context).textTheme.labelMedium?.copyWith(
            fontWeight: FontWeight.w700,
            letterSpacing: context.ar ? 0 : 1.1,
          ),
        ),
      ),
      const SizedBox(height: 12),
      _LedgerRow(
        preset: preset,
        number: '01',
        title: context.t('الرحلة', 'Trip'),
        value: 'TRP-842',
      ),
      _LedgerRow(
        preset: preset,
        number: '02',
        title: context.t('الوجهة', 'Destination'),
        value: context.t('بوابة التوزيع', 'Distribution gate'),
      ),
      _LedgerRow(
        preset: preset,
        number: '03',
        title: context.t('الوصول', 'Arrival'),
        value: '14:32',
      ),
      _LedgerRow(
        preset: preset,
        number: '04',
        title: context.t('المتبقي', 'Remaining'),
        value: context.t('٤٢ كم', '42 km'),
      ),
      const SizedBox(height: 14),
      _NextActionPanel(preset: preset),
      const SizedBox(height: 12),
      _TruckMiniSummary(preset: preset),
    ],
  );
}

class _LedgerRow extends StatelessWidget {
  const _LedgerRow({
    required this.preset,
    required this.number,
    required this.title,
    required this.value,
  });

  final LabConceptPreset preset;
  final String number;
  final String title;
  final String value;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(vertical: 12),
    decoration: BoxDecoration(
      border: Border(bottom: BorderSide(color: preset.border)),
    ),
    child: Row(
      children: [
        SizedBox(
          width: 34,
          child: Text(
            number,
            style: TextStyle(
              color: preset.primary,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
        SizedBox(
          width: 84,
          child: Text(title, style: TextStyle(color: preset.muted)),
        ),
        Expanded(
          child: Text(
            value,
            textAlign: TextAlign.end,
            style: const TextStyle(fontWeight: FontWeight.w700),
          ),
        ),
      ],
    ),
  );
}

class _TruckMiniSummary extends StatelessWidget {
  const _TruckMiniSummary({required this.preset});

  final LabConceptPreset preset;

  @override
  Widget build(BuildContext context) => LabPanel(
    preset: preset,
    padding: const EdgeInsets.all(12),
    child: Row(
      children: [
        Container(
          width: 46,
          height: 46,
          decoration: BoxDecoration(
            color: preset.primary.withValues(alpha: .12),
            borderRadius: BorderRadius.circular(preset.radiusSmall),
          ),
          child: Icon(Icons.local_shipping_rounded, color: preset.primary),
        ),
        const SizedBox(width: 11),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'TRK-204 · ر س م ٤٨٢١',
                style: TextStyle(fontWeight: FontWeight.w700),
              ),
              Text(
                context.t(
                  'شاحنتك الحالية · متصلة',
                  'Your current truck · online',
                ),
                style: Theme.of(
                  context,
                ).textTheme.bodySmall?.copyWith(color: preset.muted),
              ),
            ],
          ),
        ),
        Icon(Icons.arrow_forward_ios_rounded, size: 16, color: preset.muted),
      ],
    ),
  );
}

class _RouteBeaconTruck extends StatelessWidget {
  const _RouteBeaconTruck({required this.preset});

  final LabConceptPreset preset;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      _TruckHero(preset: preset, prominent: true),
      const SizedBox(height: 12),
      SizedBox(height: 285, child: LabMap(preset: preset, compact: true)),
      const SizedBox(height: 12),
      Row(
        children: [
          Expanded(
            child: _TruckFact(
              preset: preset,
              icon: Icons.speed_rounded,
              value: context.t('٧٢ كم/س', '72 km/h'),
              label: context.t('السرعة', 'Speed'),
            ),
          ),
          const SizedBox(width: 9),
          Expanded(
            child: _TruckFact(
              preset: preset,
              icon: Icons.explore_outlined,
              value: 'NE 42°',
              label: context.t('الاتجاه', 'Heading'),
            ),
          ),
        ],
      ),
      const SizedBox(height: 12),
      _CustodyPanel(preset: preset),
    ],
  );
}

class _NightDispatchTruck extends StatelessWidget {
  const _NightDispatchTruck({required this.preset});

  final LabConceptPreset preset;

  @override
  Widget build(BuildContext context) => Column(
    children: [
      LabPanel(
        preset: preset,
        accent: true,
        child: Column(
          children: [
            _TruckHero(preset: preset, prominent: false),
            const SizedBox(height: 15),
            Row(
              children: [
                Expanded(
                  child: _InstrumentValue(
                    preset: preset,
                    value: '72',
                    unit: context.t('كم/س', 'km/h'),
                    label: context.t('السرعة', 'SPEED'),
                  ),
                ),
                Container(width: 1, height: 54, color: preset.border),
                Expanded(
                  child: _InstrumentValue(
                    preset: preset,
                    value: '42°',
                    unit: 'NE',
                    label: context.t('الاتجاه', 'HEADING'),
                  ),
                ),
                Container(width: 1, height: 54, color: preset.border),
                Expanded(
                  child: _InstrumentValue(
                    preset: preset,
                    value: '18',
                    unit: context.t('ث', 'sec'),
                    label: context.t('آخر موقع', 'LAST FIX'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
      const SizedBox(height: 12),
      SizedBox(height: 292, child: LabMap(preset: preset, compact: true)),
      const SizedBox(height: 12),
      _CustodyPanel(preset: preset),
    ],
  );
}

class _FieldLedgerTruck extends StatelessWidget {
  const _FieldLedgerTruck({required this.preset});

  final LabConceptPreset preset;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Container(
        padding: const EdgeInsets.symmetric(vertical: 8),
        decoration: BoxDecoration(
          border: Border(
            top: BorderSide(color: preset.ink, width: 2),
            bottom: BorderSide(color: preset.border),
          ),
        ),
        child: Row(
          children: [
            Expanded(
              child: Text(
                context.t('بطاقة عهدة المركبة', 'VEHICLE CUSTODY CARD'),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontWeight: FontWeight.w700),
              ),
            ),
            const SizedBox(width: 8),
            const Spacer(),
            Text('ASSET / 204', style: TextStyle(color: preset.muted)),
          ],
        ),
      ),
      const SizedBox(height: 12),
      _TruckHero(preset: preset, prominent: false),
      const SizedBox(height: 10),
      _LedgerRow(
        preset: preset,
        number: '01',
        title: context.t('الحالة', 'Status'),
        value: context.t('في الطريق · متصلة', 'In transit · Online'),
      ),
      _LedgerRow(
        preset: preset,
        number: '02',
        title: context.t('العهدة', 'Custody'),
        value: context.t('جلسة نشطة', 'Active session'),
      ),
      _LedgerRow(
        preset: preset,
        number: '03',
        title: context.t('الموقع', 'Location'),
        value: context.t('قبل ١٨ ثانية', '18 seconds ago'),
      ),
      const SizedBox(height: 12),
      SizedBox(height: 250, child: LabMap(preset: preset, compact: true)),
      const SizedBox(height: 12),
      _CustodyPanel(preset: preset),
    ],
  );
}

class _TruckHero extends StatelessWidget {
  const _TruckHero({required this.preset, required this.prominent});

  final LabConceptPreset preset;
  final bool prominent;

  @override
  Widget build(BuildContext context) => LabPanel(
    preset: preset,
    padding: EdgeInsets.all(prominent ? 18 : 14),
    child: Row(
      children: [
        Container(
          width: prominent ? 76 : 62,
          height: prominent ? 76 : 62,
          decoration: BoxDecoration(
            color: preset.primary.withValues(alpha: .12),
            border: Border.all(color: preset.primary.withValues(alpha: .3)),
            borderRadius: BorderRadius.circular(preset.radiusSmall),
          ),
          child: Icon(
            Icons.local_shipping_rounded,
            size: prominent ? 40 : 34,
            color: preset.primary,
          ),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'TRK-204',
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                context.t('فولفو FH · ٢٠٢٤', 'Volvo FH · 2024'),
                style: TextStyle(color: preset.muted),
              ),
              const SizedBox(height: 7),
              LabStatusPill(
                preset: preset,
                label: context.t('متصلة · في الطريق', 'Online · In transit'),
                tone: preset.success,
                icon: Icons.sensors,
              ),
            ],
          ),
        ),
        Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(
              'ر س م',
              style: Theme.of(
                context,
              ).textTheme.labelSmall?.copyWith(color: preset.muted),
            ),
            Text(
              '٤٨٢١',
              style: Theme.of(
                context,
              ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700),
            ),
          ],
        ),
      ],
    ),
  );
}

class _TruckFact extends StatelessWidget {
  const _TruckFact({
    required this.preset,
    required this.icon,
    required this.value,
    required this.label,
  });

  final LabConceptPreset preset;
  final IconData icon;
  final String value;
  final String label;

  @override
  Widget build(BuildContext context) => LabPanel(
    preset: preset,
    padding: const EdgeInsets.all(13),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, color: preset.secondary, size: 20),
        const SizedBox(height: 9),
        Text(
          value,
          style: Theme.of(
            context,
          ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700),
        ),
        Text(
          label,
          style: Theme.of(
            context,
          ).textTheme.labelSmall?.copyWith(color: preset.muted),
        ),
      ],
    ),
  );
}

class _InstrumentValue extends StatelessWidget {
  const _InstrumentValue({
    required this.preset,
    required this.value,
    required this.unit,
    required this.label,
  });

  final LabConceptPreset preset;
  final String value;
  final String unit;
  final String label;

  @override
  Widget build(BuildContext context) => Column(
    children: [
      Text(
        label,
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
          color: preset.muted,
          letterSpacing: context.ar ? 0 : 1,
        ),
      ),
      const SizedBox(height: 5),
      RichText(
        text: TextSpan(
          style: Theme.of(context).textTheme.headlineSmall?.copyWith(
            color: preset.ink,
            fontWeight: FontWeight.w700,
          ),
          children: [
            TextSpan(text: value),
            TextSpan(
              text: ' $unit',
              style: Theme.of(
                context,
              ).textTheme.labelSmall?.copyWith(color: preset.primary),
            ),
          ],
        ),
      ),
    ],
  );
}

class _CustodyPanel extends StatelessWidget {
  const _CustodyPanel({required this.preset});

  final LabConceptPreset preset;

  @override
  Widget build(BuildContext context) => LabPanel(
    preset: preset,
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(Icons.verified_user_outlined, color: preset.primary),
            const SizedBox(width: 9),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    context.t('العهدة الحالية', 'Current custody'),
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                  Text(
                    context.t(
                      'جلسة قيادة نشطة · التعيين الافتراضي مطابق',
                      'Active driving session · default assignment matches',
                    ),
                    style: Theme.of(
                      context,
                    ).textTheme.bodySmall?.copyWith(color: preset.muted),
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 13),
        SizedBox(
          width: double.infinity,
          child: OutlinedButton.icon(
            onPressed: () {},
            icon: const Icon(Icons.qr_code_scanner_rounded),
            label: Text(context.t('تبديل المركبة', 'Switch vehicle')),
          ),
        ),
      ],
    ),
  );
}

Color _readableForeground(Color color) =>
    color.computeLuminance() > .42 ? const Color(0xFF17201D) : Colors.white;

class LabComponentSheet extends StatefulWidget {
  const LabComponentSheet({required this.preset, super.key});

  final LabConceptPreset preset;

  @override
  State<LabComponentSheet> createState() => _LabComponentSheetState();
}

class _LabComponentSheetState extends State<LabComponentSheet> {
  Timer? _timer;
  bool _active = false;

  @override
  void initState() {
    super.initState();
    _timer = Timer(const Duration(milliseconds: 360), () {
      if (mounted) setState(() => _active = true);
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final preset = widget.preset;
    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                LabMark(preset: preset, size: 54),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        preset.name(Localizations.localeOf(context)),
                        style: Theme.of(context).textTheme.headlineMedium
                            ?.copyWith(fontWeight: FontWeight.w700),
                      ),
                      Text(
                        preset.rationale(Localizations.localeOf(context)),
                        style: Theme.of(
                          context,
                        ).textTheme.bodyMedium?.copyWith(color: preset.muted),
                      ),
                    ],
                  ),
                ),
                LabStatusPill(
                  preset: preset,
                  label: context.t(
                    'نموذج قابل للاستبدال',
                    'Replaceable preset',
                  ),
                  tone: preset.primary,
                  icon: Icons.palette_outlined,
                ),
              ],
            ),
            const SizedBox(height: 24),
            LayoutBuilder(
              builder: (context, constraints) {
                final columns = constraints.maxWidth >= 900 ? 3 : 1;
                final width = columns == 3
                    ? (constraints.maxWidth - 32) / 3
                    : constraints.maxWidth;
                return Wrap(
                  spacing: 16,
                  runSpacing: 16,
                  children: [
                    SizedBox(
                      width: width,
                      child: _ComponentNavigation(
                        preset: preset,
                        active: _active,
                      ),
                    ),
                    SizedBox(
                      width: width,
                      child: _ComponentControls(preset: preset),
                    ),
                    SizedBox(
                      width: width,
                      child: _ComponentStates(preset: preset),
                    ),
                    SizedBox(
                      width: columns == 3
                          ? width * 2 + 16
                          : constraints.maxWidth,
                      child: _MotionStage(preset: preset, active: _active),
                    ),
                    SizedBox(
                      width: width,
                      child: _ComponentList(preset: preset),
                    ),
                  ],
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}

class _ComponentNavigation extends StatelessWidget {
  const _ComponentNavigation({required this.preset, required this.active});

  final LabConceptPreset preset;
  final bool active;

  @override
  Widget build(BuildContext context) => LabPanel(
    preset: preset,
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _SheetTitle(
          preset: preset,
          number: '01',
          ar: 'لغة التنقل',
          en: 'Navigation language',
        ),
        const SizedBox(height: 14),
        if (preset.id == LabConcept.routeBeacon)
          Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: preset.ink,
              borderRadius: BorderRadius.circular(preset.radiusSmall),
            ),
            child: Row(
              children: [
                for (var i = 0; i < 3; i++)
                  Expanded(
                    child: AnimatedContainer(
                      duration: _duration(context, preset.motion.standard),
                      padding: const EdgeInsets.symmetric(vertical: 11),
                      decoration: BoxDecoration(
                        color: (active ? i == 1 : i == 0)
                            ? preset.primary
                            : Colors.transparent,
                        borderRadius: BorderRadius.circular(preset.radiusSmall),
                      ),
                      child: Icon(
                        [
                          Icons.today_outlined,
                          Icons.route,
                          Icons.local_shipping,
                        ][i],
                        size: 20,
                        color: (active ? i == 1 : i == 0)
                            ? Colors.white
                            : Colors.white60,
                      ),
                    ),
                  ),
              ],
            ),
          )
        else if (preset.id == LabConcept.nightDispatch)
          Stack(
            children: [
              Container(
                height: 50,
                decoration: BoxDecoration(
                  border: Border.all(color: preset.border),
                  borderRadius: BorderRadius.circular(preset.radiusSmall),
                ),
              ),
              AnimatedAlign(
                duration: _duration(context, preset.motion.emphasized),
                curve: Curves.easeInOutCubic,
                alignment: active
                    ? AlignmentDirectional.center
                    : AlignmentDirectional.centerStart,
                child: Container(
                  width: 86,
                  height: 50,
                  decoration: BoxDecoration(
                    color: preset.primary.withValues(alpha: .16),
                    border: Border.all(color: preset.primary),
                    borderRadius: BorderRadius.circular(preset.radiusSmall),
                  ),
                  child: Icon(Icons.radar_rounded, color: preset.primary),
                ),
              ),
            ],
          )
        else
          Column(
            children: [
              for (var i = 0; i < 3; i++)
                Container(
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  decoration: BoxDecoration(
                    border: Border(
                      bottom: BorderSide(color: preset.border),
                      left: BorderSide(
                        color: (active ? i == 1 : i == 0)
                            ? preset.primary
                            : Colors.transparent,
                        width: 3,
                      ),
                    ),
                  ),
                  child: Row(
                    children: [
                      Text(
                        (i + 1).toString().padLeft(2, '0'),
                        style: TextStyle(color: preset.muted),
                      ),
                      const SizedBox(width: 14),
                      Icon(
                        [
                          Icons.today_outlined,
                          Icons.route,
                          Icons.local_shipping,
                        ][i],
                        size: 18,
                      ),
                      const SizedBox(width: 9),
                      Text(
                        [
                          context.t('اليوم', 'Today'),
                          context.t('الرحلات', 'Trips'),
                          context.t('الأسطول', 'Fleet'),
                        ][i],
                      ),
                    ],
                  ),
                ),
            ],
          ),
      ],
    ),
  );
}

class _ComponentControls extends StatelessWidget {
  const _ComponentControls({required this.preset});

  final LabConceptPreset preset;

  @override
  Widget build(BuildContext context) => LabPanel(
    preset: preset,
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _SheetTitle(
          preset: preset,
          number: '02',
          ar: 'الأزرار والمدخلات',
          en: 'Actions & inputs',
        ),
        const SizedBox(height: 14),
        TextField(
          decoration: InputDecoration(
            hintText: context.t('ابحث برقم المركبة', 'Search by vehicle code'),
            prefixIcon: const Icon(Icons.search_rounded),
          ),
        ),
        const SizedBox(height: 11),
        Row(
          children: [
            Expanded(
              child: FilledButton(
                onPressed: () {},
                child: Text(context.t('إجراء أساسي', 'Primary action')),
              ),
            ),
            const SizedBox(width: 8),
            IconButton.outlined(
              onPressed: () {},
              tooltip: context.t('تصفية', 'Filter'),
              icon: const Icon(Icons.tune_rounded),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 7,
          runSpacing: 7,
          children: [
            LabStatusPill(
              preset: preset,
              label: context.t('مباشر', 'Live'),
              tone: preset.success,
            ),
            LabStatusPill(
              preset: preset,
              label: context.t('متأخر', 'Delayed'),
              tone: preset.signal,
            ),
            LabStatusPill(
              preset: preset,
              label: context.t('غير متصل', 'Offline'),
              tone: preset.danger,
            ),
          ],
        ),
      ],
    ),
  );
}

class _ComponentStates extends StatelessWidget {
  const _ComponentStates({required this.preset});

  final LabConceptPreset preset;

  @override
  Widget build(BuildContext context) => LabPanel(
    preset: preset,
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _SheetTitle(
          preset: preset,
          number: '03',
          ar: 'حالات النظام',
          en: 'System states',
        ),
        const SizedBox(height: 14),
        _StateLine(
          preset: preset,
          icon: Icons.cloud_off_outlined,
          tone: preset.danger,
          title: context.t('المركبة غير متصلة', 'Vehicle offline'),
          body: context.t(
            'آخر موقع قبل ١٢ دقيقة',
            'Last position 12 minutes ago',
          ),
        ),
        const SizedBox(height: 12),
        _StateLine(
          preset: preset,
          icon: Icons.route_outlined,
          tone: preset.secondary,
          title: context.t('لا توجد رحلة حالية', 'No current trip'),
          body: context.t(
            'المركبة ما زالت متاحة',
            'The vehicle remains available',
          ),
        ),
        const SizedBox(height: 16),
        for (final fraction in [.85, .62, .74])
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: FractionallySizedBox(
              widthFactor: fraction,
              child: Container(height: 10, color: preset.surfaceStrong),
            ),
          ),
      ],
    ),
  );
}

class _StateLine extends StatelessWidget {
  const _StateLine({
    required this.preset,
    required this.icon,
    required this.tone,
    required this.title,
    required this.body,
  });

  final LabConceptPreset preset;
  final IconData icon;
  final Color tone;
  final String title;
  final String body;

  @override
  Widget build(BuildContext context) => Row(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Icon(icon, color: tone, size: 20),
      const SizedBox(width: 10),
      Expanded(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: const TextStyle(fontWeight: FontWeight.w700)),
            Text(
              body,
              style: Theme.of(
                context,
              ).textTheme.bodySmall?.copyWith(color: preset.muted),
            ),
          ],
        ),
      ),
    ],
  );
}

class _MotionStage extends StatelessWidget {
  const _MotionStage({required this.preset, required this.active});

  final LabConceptPreset preset;
  final bool active;

  @override
  Widget build(BuildContext context) => LabPanel(
    preset: preset,
    accent: true,
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _SheetTitle(
          preset: preset,
          number: '04',
          ar: 'لغة الحركة',
          en: 'Motion language',
        ),
        const SizedBox(height: 14),
        Text(
          context.t(
            'ثلاث حركات مترابطة: انتقال التحديد، تقدم الرحلة، ودخول التنبيه.',
            'Three coordinated cues: selection shift, trip progress, and notification entry.',
          ),
          style: TextStyle(color: preset.muted),
        ),
        const SizedBox(height: 18),
        Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Expanded(
              child: TweenAnimationBuilder<double>(
                tween: Tween(begin: .22, end: active ? .68 : .22),
                duration: _duration(context, preset.motion.emphasized),
                curve: Curves.easeInOutCubic,
                builder: (context, value, _) => Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          context.t('تقدم الرحلة', 'Trip progress'),
                          style: const TextStyle(fontWeight: FontWeight.w700),
                        ),
                        const Spacer(),
                        Text(
                          '${(value * 100).round()}%',
                          style: TextStyle(
                            color: preset.primary,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    LinearProgressIndicator(
                      value: value,
                      minHeight: 8,
                      backgroundColor: preset.surfaceStrong,
                      color: preset.primary,
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(width: 20),
            Expanded(
              child: AnimatedSlide(
                duration: _duration(context, preset.motion.standard),
                curve: Curves.easeOutCubic,
                offset: active ? Offset.zero : const Offset(0, .35),
                child: AnimatedOpacity(
                  duration: _duration(context, preset.motion.fast),
                  opacity: active ? 1 : 0,
                  child: Container(
                    padding: const EdgeInsets.all(13),
                    decoration: BoxDecoration(
                      color: preset.surface,
                      border: Border.all(color: preset.signal),
                      borderRadius: BorderRadius.circular(preset.radiusSmall),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.notifications_active, color: preset.signal),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                context.t(
                                  'اقتراب من الوجهة',
                                  'Approaching destination',
                                ),
                                style: const TextStyle(
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              Text(
                                context.t(
                                  'متبقٍ ٣ دقائق',
                                  '3 minutes remaining',
                                ),
                                style: Theme.of(context).textTheme.bodySmall
                                    ?.copyWith(color: preset.muted),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ],
    ),
  );
}

class _ComponentList extends StatelessWidget {
  const _ComponentList({required this.preset});

  final LabConceptPreset preset;

  @override
  Widget build(BuildContext context) => LabPanel(
    preset: preset,
    padding: EdgeInsets.zero,
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.all(16),
          child: _SheetTitle(
            preset: preset,
            number: '05',
            ar: 'قائمة تشغيلية',
            en: 'Operational list',
          ),
        ),
        for (var index = 0; index < 3; index++)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 11),
            decoration: BoxDecoration(
              color: index == 0 ? preset.primary.withValues(alpha: .08) : null,
              border: Border(top: BorderSide(color: preset.border)),
            ),
            child: Row(
              children: [
                Text(
                  (index + 1).toString().padLeft(2, '0'),
                  style: TextStyle(
                    color: index == 0 ? preset.primary : preset.muted,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    labTrucks[index].code,
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                ),
                Text(
                  context.ar
                      ? labTrucks[index].status
                      : _statusEn(labTrucks[index].status),
                  style: Theme.of(
                    context,
                  ).textTheme.labelSmall?.copyWith(color: preset.muted),
                ),
              ],
            ),
          ),
      ],
    ),
  );
}

class _SheetTitle extends StatelessWidget {
  const _SheetTitle({
    required this.preset,
    required this.number,
    required this.ar,
    required this.en,
  });

  final LabConceptPreset preset;
  final String number;
  final String ar;
  final String en;

  @override
  Widget build(BuildContext context) => Row(
    children: [
      Text(
        number,
        style: Theme.of(context).textTheme.labelMedium?.copyWith(
          color: preset.primary,
          fontWeight: FontWeight.w700,
        ),
      ),
      const SizedBox(width: 9),
      Expanded(
        child: Text(
          context.t(ar, en),
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: Theme.of(
            context,
          ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
        ),
      ),
    ],
  );
}

Duration _duration(BuildContext context, Duration value) =>
    MediaQuery.maybeOf(context)?.disableAnimations == true
    ? Duration.zero
    : value;
