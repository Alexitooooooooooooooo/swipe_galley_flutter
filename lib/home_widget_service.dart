import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:home_widget/home_widget.dart';

/// Puente con el widget de pantalla de inicio (Android).
class HomeWidgetService {
  // Solo el nombre de la clase: el plugin lo resuelve contra el applicationId.
  static const String _androidProvider = 'DailyWidgetProvider';

  /// Guarda la meta/avance diario y refresca el widget.
  static Future<void> syncStats({
    required int goal,
    required int done,
    required String date,
  }) async {
    try {
      await HomeWidget.saveWidgetData<int>('dgo_goal', goal);
      await HomeWidget.saveWidgetData<int>('dgo_done', done);
      await HomeWidget.saveWidgetData<String>('dgo_date', date);
      await HomeWidget.updateWidget(androidName: _androidProvider);
    } catch (e) {
      debugPrint('HomeWidgetService.syncStats error: $e');
    }
  }

  /// Guarda la foto que se mostrará al frente del widget (y su id) y lo refresca.
  ///
  /// Usa un archivo nuevo en cada actualización para evitar que el launcher
  /// muestre una imagen cacheada.
  static Future<void> syncPhoto(Uint8List? bytes, {String? assetId}) async {
    try {
      if (bytes != null && bytes.isNotEmpty) {
        final String key = 'dgo_img_${DateTime.now().millisecondsSinceEpoch}';
        final String path = await HomeWidget.saveFile(key, bytes, extension: 'jpg');
        final String? previous = await HomeWidget.getWidgetData<String>('dgo_image');
        await HomeWidget.saveWidgetData<String>('dgo_image', path);
        if (previous != null && previous.isNotEmpty && previous != path) {
          try {
            final file = File(previous);
            if (await file.exists()) await file.delete();
          } catch (_) {
            // Si no se puede borrar la anterior, no pasa nada.
          }
        }
        debugPrint('HomeWidgetService: foto -> $path (${bytes.length} bytes)');
      } else {
        await HomeWidget.saveWidgetData<String>('dgo_image', null);
      }
      await HomeWidget.saveWidgetData<String>('dgo_image_id', assetId);
      await HomeWidget.updateWidget(androidName: _androidProvider);
    } catch (e) {
      debugPrint('HomeWidgetService.syncPhoto error: $e');
    }
  }

  /// Si la app se abrió tocando el widget, devuelve el id de la foto a mostrar.
  static Future<String?> initialAssetId() async {
    try {
      final uri = await HomeWidget.initiallyLaunchedFromHomeWidget();
      return uri?.queryParameters['asset'];
    } catch (_) {
      return null;
    }
  }

  /// Emite el id de la foto cuando se toca el widget con la app ya abierta.
  static Stream<String?> assetIdClicks() {
    try {
      return HomeWidget.widgetClicked.map((uri) => uri?.queryParameters['asset']);
    } catch (_) {
      return const Stream<String?>.empty();
    }
  }
}
