import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:hatud_tricycle_app/common/my_colors.dart';
import 'package:hatud_tricycle_app/common/my_theme.dart';
import 'package:hatud_tricycle_app/features/landing/landing_screen.dart';
import 'package:hatud_tricycle_app/features/landing/bloc/bloc.dart';
import 'package:hatud_tricycle_app/repo/pref_manager.dart';
import 'package:hatud_tricycle_app/l10n/app_localizations.dart';
import 'package:hatud_tricycle_app/application.dart';
import 'package:hatud_tricycle_app/route_generator.dart';

import 'injections.dart' as di;

// Custom delegate to ensure MaterialLocalizations always uses English
// even when AppLocalizations uses Waray-Waray
class _EnglishMaterialLocalizationsDelegate extends LocalizationsDelegate<MaterialLocalizations> {
  const _EnglishMaterialLocalizationsDelegate();

  @override
  bool isSupported(Locale locale) => true;

  @override
  Future<MaterialLocalizations> load(Locale locale) {
    // Always load English MaterialLocalizations regardless of the locale parameter
    return GlobalMaterialLocalizations.delegate.load(const Locale('en', ''));
  }

  @override
  bool shouldReload(_EnglishMaterialLocalizationsDelegate old) => false;
}

// Custom delegate to ensure WidgetsLocalizations always uses English
// even when AppLocalizations uses Waray-Waray
class _EnglishWidgetsLocalizationsDelegate extends LocalizationsDelegate<WidgetsLocalizations> {
  const _EnglishWidgetsLocalizationsDelegate();

  @override
  bool isSupported(Locale locale) => true;

  @override
  Future<WidgetsLocalizations> load(Locale locale) {
    // Always load English WidgetsLocalizations regardless of the locale parameter
    return GlobalWidgetsLocalizations.delegate.load(const Locale('en', ''));
  }

  @override
  bool shouldReload(_EnglishWidgetsLocalizationsDelegate old) => false;
}

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // WebView initialization is handled automatically by plugins
  // webview_flutter and flutter_inappwebview both support Windows
  print('App initialized - WebView ready for Windows');

  /*For android status bar color.For iOS please check ios/runner appdelegate file*/
  SystemChrome.setSystemUIOverlayStyle(
    SystemUiOverlayStyle.light.copyWith(
      statusBarColor: kPrimaryColor, //Android
    ),
  );

  //This code will ready our repo object for entire app.
  await di.initDependencies();

  await PrefManager.getInstance();

  runApp(MyApp());
}

class MyApp extends StatefulWidget {
  @override
  _MyAppState createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  Locale _locale = Locale('en', '');

  @override
  void initState() {
    super.initState();
    _loadLocale();

    // Set up locale change callback
    application.onLocaleChanged = (Locale locale) {
      if (mounted) {
        setState(() {
          _locale = locale;
          print('Locale updated in MyApp to: ${locale.languageCode}');
        });
      }
    };
  }

  _loadLocale() async {
    PrefManager pref = await PrefManager.getInstance();
    setState(() {
      _locale = Locale(pref.defaultLanCode, '');
    });
  }

  @override
  Widget build(BuildContext context) {
    // Get fallback locale for MaterialLocalizations
    // GlobalMaterialLocalizations doesn't support Waray-Waray (war)
    // Use English as fallback for MaterialLocalizations when Waray-Waray is selected
    final materialLocale = _locale.languageCode == 'war' 
        ? const Locale('en', '') 
        : _locale;
    
    // Ensure MaterialApp is the root widget with proper localization setup
    return MaterialApp(
      key: ValueKey(_locale.languageCode), // Force rebuild when locale changes
      title: 'HATUD - Tricycle Ride App',
      debugShowCheckedModeBanner: false,
      theme: kAppThemeData,
      // Critical: These delegates must be present for MaterialLocalizations
      localizationsDelegates: const [
        AppLocalizations.delegate, // Our custom localizations (supports Waray-Waray)
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: const [
        Locale('en', ''),
        Locale('tl', ''),
        Locale('war', ''),
        Locale('fr', ''),
      ],
      // Use materialLocale (English when Waray-Waray) for MaterialLocalizations
      // This prevents the "locale not supported" warning and ensures MaterialLocalizations works
      locale: materialLocale,
      localeResolutionCallback: (locale, supportedLocales) {
        return materialLocale;
      },
      // Use builder to provide AppLocalizations with the actual locale (Waray-Waray)
      // while ensuring MaterialLocalizations is always available
      builder: (context, child) {
        // Create a Localizations widget that provides AppLocalizations in Waray-Waray
        // while ensuring MaterialLocalizations uses English (from MaterialApp's materialLocale)
        // We need to include all delegates to ensure MaterialLocalizations is available
        return Localizations(
          locale: _locale, // Use actual locale (Waray-Waray) for AppLocalizations
          delegates: [
            AppLocalizations.delegate, // This will use _locale (Waray-Waray)
            // For MaterialLocalizations and WidgetsLocalizations, we need to ensure they use English
            // So we create custom delegates that always use English
            const _EnglishMaterialLocalizationsDelegate(),
            const _EnglishWidgetsLocalizationsDelegate(),
            GlobalCupertinoLocalizations.delegate,
          ],
          child: MediaQuery(
            data: MediaQuery.of(context),
            child: child ?? const SizedBox.shrink(),
          ),
        );
      },
      onGenerateRoute: RouteGenerator.generateRoute,
      home: BlocProvider(
        create: (context) => LandingBloc(),
        child: LandingScreen(_locale),
      ),
    );
  }
}
