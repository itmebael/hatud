import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;

class AppTranslations {
  final Locale locale;
  static Map<dynamic, dynamic>? _localisedValues;

  AppTranslations(this.locale);

  static AppTranslations of(BuildContext context) {
    final result = Localizations.of<AppTranslations>(context, AppTranslations);
    assert(result != null, 'AppTranslations not found in context');
    return result!;
  }

  static Future<AppTranslations> load(Locale locale) async {
    AppTranslations appTranslations = AppTranslations(locale);
    String jsonContent = await rootBundle
        .loadString("assets/locale/localization_${locale.languageCode}.json");
    _localisedValues = json.decode(jsonContent) as Map<String, dynamic>;
    return appTranslations;
  }

  String get currentLanguage => locale.languageCode;

  String text(String key) {
    return _localisedValues?[key] ?? "$key not found";
  }
}
