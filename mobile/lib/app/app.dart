import 'package:flutter/material.dart';

import 'router.dart';
import 'theme.dart';

class ControlLaboralApp extends StatelessWidget {
  const ControlLaboralApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      title: 'Control Laboral',
      debugShowCheckedModeBanner: false,
      theme: buildAppTheme(),
      routerConfig: appRouter,
    );
  }
}
