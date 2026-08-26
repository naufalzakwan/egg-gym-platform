import 'package:egg_gym/core/utils/public_storage_url.dart';

/// Equipment images are public catalog assets. Resolve them with either the
/// authenticated session host or the last responding public API host.
String? resolveEquipmentImageUrl(String? imagePath) =>
    resolvePublicStorageUrl(imagePath);
