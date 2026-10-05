import 'package:flutter/services.dart';

/// Puente nativo (Android) para mover archivos usando "All files access",
/// que evita pedir permiso de escritura en cada operación.
class NativeMover {
  static const MethodChannel _channel = MethodChannel('swipegallery/native');

  /// ¿La app tiene "Acceso a todos los archivos" (MANAGE_EXTERNAL_STORAGE)?
  static Future<bool> hasAllFilesAccess() async {
    try {
      return (await _channel.invokeMethod<bool>('hasAllFilesAccess')) ?? false;
    } catch (_) {
      return false;
    }
  }

  /// Mueve los assets (por id de MediaStore) a la carpeta [relativePath].
  static Future<bool> moveToAlbum(List<String> ids, String relativePath) async {
    try {
      return (await _channel.invokeMethod<bool>('moveToAlbum', {
            'ids': ids,
            'path': relativePath,
          })) ??
          false;
    } catch (_) {
      return false;
    }
  }
}
