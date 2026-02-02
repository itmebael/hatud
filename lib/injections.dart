import 'dart:io' show Platform;
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:internet_connection_checker/internet_connection_checker.dart';
import 'package:hatud_tricycle_app/repo/api_provider.dart';
import 'package:hatud_tricycle_app/repo/network_info.dart';
import 'package:hatud_tricycle_app/repo/pref_manager.dart';
import 'package:hatud_tricycle_app/repo/repo_provider.dart';
import 'package:get_it/get_it.dart';

Future<void> initDependencies() async {
  final getIt = GetIt.instance;

  await PrefManager.getInstance();

  // Create network info with platform check
  // internet_connection_checker doesn't work on web, so use a web-compatible version
  NetworkInfo networkInfo;
  
  if (kIsWeb || Platform.isWindows) {
    // For web/Windows, use a simple implementation that always returns true
    // (web always has internet when browser is connected)
    networkInfo = WebNetworkInfo();
  } else {
    // For mobile platforms, use InternetConnectionChecker
    try {
      networkInfo = NetworkInfoImpl(InternetConnectionChecker());
    } catch (e) {
      print('Warning: InternetConnectionChecker failed, using WebNetworkInfo: $e');
      networkInfo = WebNetworkInfo();
    }
  }

  // Repository
  getIt.registerLazySingleton<RepoProvider>(
    () => RepoProvider(
      apiProvider: APIProviderIml(),
      networkInfo: networkInfo,
    ),
  );
}
