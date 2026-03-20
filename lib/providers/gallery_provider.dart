import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:photo_manager/photo_manager.dart';

class GalleryProvider with ChangeNotifier {

  List<AssetEntity> _images = [];
  List<AssetEntity> _pendingDeletePhotos = [];
  bool _isLoading = true;
  final Map<String, Uint8List?> _thumbnailById = {};
  final List<_SwipeAction> _history = [];

  List<AssetEntity> get images => _images;
  List<AssetEntity> get pendingDeletePhotos => _pendingDeletePhotos;
  bool get isLoading => _isLoading;

  Uint8List? getThumbnailFor(AssetEntity asset) => _thumbnailById[asset.id];

  GalleryProvider() {
    // No cargar las imágenes aquí, se llamará explícitamente cuando entremos al HomeScreen
  }

  Future<void> loadImages() async {
    _isLoading = true;
    notifyListeners();
    // 1. Pedir permisos
    final PermissionState ps = await PhotoManager.requestPermissionExtend();
    if (ps.hasAccess) {
      // 2. Obtener los álbumes (solo imágenes)
      List<AssetPathEntity> albums = await PhotoManager.getAssetPathList(
        type: RequestType.image,
        hasAll: true,
      );
      
      if (albums.isNotEmpty) {
        // Buscar el primer álbum que realmente tenga fotos (a veces el álbum 0 viene vacío)
        for (var album in albums) {
          final count = await album.assetCountAsync;
          if (count > 0) {
            List<AssetEntity> photos = await album.getAssetListPaged(page: 0, size: 50); // Carga de 50 en 50
            _images = photos;
            _pendingDeletePhotos.clear();
            _history.clear();
            // Pre-calcular miniaturas para evitar desajustes entre carta y foto
            _thumbnailById.clear();
            for (final asset in _images) {
              try {
                final bytes = await asset
                    .thumbnailDataWithSize(const ThumbnailSize(320, 420));
                _thumbnailById[asset.id] = bytes;
              } catch (_) {
                _thumbnailById[asset.id] = null;
              }
            }
            break;
          }
        }
      }
    } else {
      await PhotoManager.openSetting();
    }
    _isLoading = false;
    notifyListeners();
  }

  Future<void> handleSwipe(int index, bool delete) async {
    final asset = _images[index];
    _history.add(_SwipeAction(asset, delete));
    if (delete) {
      // Solo agregar al array de pendientes, no borrar aún
      _pendingDeletePhotos.add(asset);
    }
    // Sacar de la lista principal
    _images.removeAt(index);
    // Mantener el cache por id (no hace falta borrar aquí)
    notifyListeners();
  }

  Future<void> confirmDeleteAll() async {
    if (_pendingDeletePhotos.isEmpty) return;
    try {
      final ids = _pendingDeletePhotos.map((a) => a.id).toList();
      final List<String> result = await PhotoManager.editor.deleteWithIds(ids);
      if (result.isNotEmpty) {
        print("Fotos eliminadas exitosamente");
      }
      _pendingDeletePhotos.clear();
      notifyListeners();
    } catch (e) {
      print("Error al borrar: $e");
    }
  }

  void removeFromPending(int index) {
    _pendingDeletePhotos.removeAt(index);
    notifyListeners();
  }

  void undoLastAction() {
    if (_history.isEmpty) return;
    final last = _history.removeLast();

    // Si la última acción fue "enviar a eliminar", quitarla de pendientes
    if (last.delete) {
      _pendingDeletePhotos.removeWhere((a) => a.id == last.asset.id);
    }

    // Volver a agregar la foto al inicio de la galería principal si no está ya
    final alreadyInMain = _images.any((a) => a.id == last.asset.id);
    if (!alreadyInMain) {
      _images.insert(0, last.asset);
    }

    notifyListeners();
  }
}

class _SwipeAction {
  final AssetEntity asset;
  final bool delete;

  _SwipeAction(this.asset, this.delete);
}