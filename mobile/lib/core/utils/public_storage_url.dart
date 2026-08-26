import 'package:egg_gym/data/services/app_session_service.dart';
import 'package:egg_gym/data/services/backend_api_config.dart';

String? resolvePublicStorageUrl(String? rawPath) {
  final path = rawPath?.trim();
  if (path == null || path.isEmpty) return null;
  if (path.startsWith('http://') || path.startsWith('https://')) return path;

  final baseUrl = AppSessionService.instance.currentSession?.baseUrl ??
      BackendApiConfig.activePublicBaseUrl;
  if (baseUrl == null || baseUrl.isEmpty) return null;
  final cleanBase = baseUrl.replaceAll(RegExp(r'/+$'), '');
  final cleanPath = path.replaceAll(RegExp(r'^/+'), '');
  if (cleanPath == 'storage' || cleanPath.startsWith('storage/')) {
    return '$cleanBase/$cleanPath';
  }
  return '$cleanBase/storage/$cleanPath';
}
