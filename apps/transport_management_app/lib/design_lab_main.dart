import 'package:flutter/material.dart';

import 'design_lab/design_lab_app.dart';
import 'design_lab/design_lab_models.dart';

const _profile = String.fromEnvironment(
  'APP_PROFILE',
  defaultValue: 'development',
);

void main() {
  if (_profile.toLowerCase() != 'development') {
    runApp(const _UnavailableDesignLab());
    return;
  }
  runApp(DesignLabApp(configuration: DesignLabConfiguration.fromUri(Uri.base)));
}

class _UnavailableDesignLab extends StatelessWidget {
  const _UnavailableDesignLab();

  @override
  Widget build(BuildContext context) => const MaterialApp(
    home: Scaffold(
      body: Center(child: Text('Design Lab is available in Development only.')),
    ),
  );
}
