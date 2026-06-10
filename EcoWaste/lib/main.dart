import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
// Note: flutter_localizations may not be listed in pubspec.yaml for some projects.
// If you add it as a dependency, you can re-enable the global localization delegates.
import 'package:provider/provider.dart';
import 'package:flutter/cupertino.dart';
import 'providers/app_provider.dart';
import 'themes/app_themes.dart';
import 'l10n/app_localizations.dart';
import 'screens/splash_screen.dart';
import 'screens/login_screen.dart';
import 'screens/register_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final appProvider = AppProvider();
  await appProvider.init();
  runApp(
    ChangeNotifierProvider.value(
      value: appProvider,
      child: const EcoWasteApp(),
    ),
  );
}

class EcoWasteApp extends StatelessWidget {
  const EcoWasteApp({super.key});

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppProvider>();

    return MaterialApp(
      title: 'EcoWaste – Civic Intelligence',
      debugShowCheckedModeBanner: false,
      theme: AppThemes.light,
      darkTheme: AppThemes.dark,
      themeMode: app.themeMode,
      locale: app.locale,
      supportedLocales: AppLocalizations.supportedLocales,
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate, // ADD THIS
        GlobalWidgetsLocalizations.delegate, // ADD THIS
        GlobalCupertinoLocalizations.delegate, // ADD THIS
      ],
      home: const SplashScreen(),
      routes: {
        '/login': (_) => const LoginScreen(),
        '/register': (_) => const RegisterScreen(),
      },
    );
  }
}
