import 'dart:convert';

import 'package:dio/dio.dart';

/// Loads a configured MapLibre style once per locale and replaces only
/// name-bearing label expressions. Sources, glyphs, sprites and attribution are
/// retained verbatim.
final class LocaleAwareMapStyle {
  LocaleAwareMapStyle._();

  static final Map<String, Future<String>> _cache = {};

  static Future<String> resolve(String style, String languageCode) {
    final locale = languageCode.toLowerCase().startsWith('ar') ? 'ar' : 'en';
    return _cache.putIfAbsent('$locale\u0000$style', () async {
      final dynamic document = style.trimLeft().startsWith('{')
          ? jsonDecode(style)
          : (await Dio().get<dynamic>(style)).data;
      final map = document is String
          ? jsonDecode(document) as Map<String, dynamic>
          : Map<String, dynamic>.from(document as Map);
      return jsonEncode(transform(map, locale));
    });
  }

  static Map<String, dynamic> transform(
    Map<String, dynamic> source,
    String languageCode,
  ) {
    final result = jsonDecode(jsonEncode(source)) as Map<String, dynamic>;
    final arabic = languageCode.toLowerCase().startsWith('ar');
    final expression = arabic
        ? <dynamic>[
            'coalesce',
            ['get', 'name:ar'],
            ['get', 'name:nonlatin'],
            ['get', 'name'],
            ['get', 'name:latin'],
            ['get', 'name_en'],
          ]
        : <dynamic>[
            'coalesce',
            ['get', 'name:latin'],
            ['get', 'name_en'],
            ['get', 'name'],
            ['get', 'name:nonlatin'],
          ];
    for (final dynamic rawLayer
        in result['layers'] as List<dynamic>? ?? const []) {
      final layer = rawLayer as Map<String, dynamic>;
      final layout = layer['layout'];
      if (layout is! Map<String, dynamic>) continue;
      final textField = layout['text-field'];
      if (!_containsNameLookup(textField)) continue;
      layout['text-field'] = expression;
    }
    return result;
  }

  static bool _containsNameLookup(dynamic value) {
    if (value is String) {
      return value.contains('name:latin') ||
          value.contains('name:nonlatin') ||
          value.contains('name_en');
    }
    if (value is List) return value.any(_containsNameLookup);
    if (value is Map) return value.values.any(_containsNameLookup);
    return false;
  }

  static void clearCacheForTests() => _cache.clear();
}
