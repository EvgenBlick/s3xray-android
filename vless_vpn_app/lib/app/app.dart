import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter/material.dart';

import '../l10n/app_strings.dart';
import '../features/home/presentation/home_screen.dart';

class VlessVpnApp extends StatelessWidget {
  const VlessVpnApp({super.key});

  @override
  Widget build(BuildContext context) {
    final ColorScheme colorScheme = ColorScheme.fromSeed(
      seedColor: const Color(0xFF0F766E),
      brightness: Brightness.light,
    );

    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Samurai Service',
      locale: const Locale('ru'),
      supportedLocales: AppStrings.supportedLocales,
      localizationsDelegates: const <LocalizationsDelegate<dynamic>>[
        AppStrings.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      theme: ThemeData(
        colorScheme: colorScheme,
        scaffoldBackgroundColor: const Color(0xFFF4F7F6),
        useMaterial3: true,
      ),
      home: const HomeScreen(),
    );
  }
}
