import 'package:internet_connection_checker/internet_connection_checker.dart';

abstract class NetworkInfo {
  Future<bool> get isConnected;
}

class NetworkInfoImpl implements NetworkInfo {
  final InternetConnectionChecker connectionChecker;

  NetworkInfoImpl(this.connectionChecker);

  @override
  Future<bool> get isConnected => connectionChecker.hasConnection;
}

/// Web-compatible NetworkInfo implementation
/// For web/Windows platforms where InternetConnectionChecker doesn't work
class WebNetworkInfo implements NetworkInfo {
  @override
  Future<bool> get isConnected async {
    // For web/Windows, if the app is running, assume internet is available
    // The browser/webview context implies connectivity
    // This avoids the InternetAddress error on unsupported platforms
    return true;
  }
}