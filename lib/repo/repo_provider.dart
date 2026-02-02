// no Flutter UI imports needed in repo provider
import 'package:hatud_tricycle_app/repo/api_provider.dart';
import 'package:hatud_tricycle_app/repo/network_info.dart';

class RepoProvider {
  final APIProviderIml apiProvider;
  final NetworkInfo networkInfo;

  const RepoProvider({
    required this.apiProvider,
    required this.networkInfo,
  });
}
