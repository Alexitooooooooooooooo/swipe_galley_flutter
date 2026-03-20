import 'package:flutter/material.dart';
import 'package:photo_manager/photo_manager.dart';
import 'package:permission_handler/permission_handler.dart';

class GalleryProvider with ChangeNotifier {
  List<AssetEntity> _images = [];
  bool _isLoading = true;

  List<AssetEntity> get images => _images;
  bool get isLoading => _isLoading;

  GalleryProvider() {
    _loadImages();
  }

  Future<void> _loadImages() async {
    // 1. Pedir permisos
    final PermissionState ps = await PhotoManager.requestPermissionExtend();
    if (ps.isAuth) {
      // 2. Obtener los álbumes (solo imágenes)
      List<AssetPathEntity> albums = await PhotoManager.getAssetPathList(type: RequestType.image);
      
      if (albums.isNotEmpty) {
        // 3. Cargar las fotos del álbum principal ("Recientes")
        List<AssetEntity> photos = await albums[0].getAssetListPaged(page: 0, size: 50); // Carga de 50 en 50
        _images = photos;
      }
    } else {
      await openAppSettings();
    }
    _isLoading = false;
    notifyListeners();
  }

  Future<void> handleSwipe(int index, bool delete) async {
    if (delete) {
      // Lógica para borrar la imagen del dispositivo
      final asset = _images[index];
      try {
        // PhotoManager tiene un método para intentar borrar
        final List<String> result = await PhotoManager.editor.deleteWithIds([asset.id]);
        if (result.isNotEmpty) {
          print("Foto borrada exitosamente");
        }
      } catch (e) {
        print("Error al borrar: $e");
      }
    }
    // Independientemente de si se borra o se conserva, la sacamos de nuestra lista actual
    _images.removeAt(index);
    notifyListeners();
  }
}