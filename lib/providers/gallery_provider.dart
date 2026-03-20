import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:photo_manager/photo_manager.dart';


class GalleryProvider with ChangeNotifier {
  List<AssetEntity> _images = [];
  List<AssetEntity> _pendingDeletePhotos = [];
  bool _isLoading = true;
  final Map<String, Uint8List?> _thumbnailById = {};
  final List<_SwipeAction> _history = [];

  // NUEVO: Para paginación random eficiente
  int _totalCount = 0;
  Set<int> _usedIndexes = {};
  int _batchSize = 50;
  AssetPathEntity? _allAlbum;

  List<AssetEntity> get images => _images;
  List<AssetEntity> get pendingDeletePhotos => _pendingDeletePhotos;
  bool get isLoading => _isLoading;

  Uint8List? getThumbnailFor(AssetEntity asset) => _thumbnailById[asset.id];

  GalleryProvider();

  Future<void> loadImages() async {
    _isLoading = true;
    notifyListeners();
    final PermissionState ps = await PhotoManager.requestPermissionExtend();
    if (ps.hasAccess) {
      // Obtener solo el álbum "All"
      List<AssetPathEntity> albums = await PhotoManager.getAssetPathList(
        type: RequestType.image,
        hasAll: true,
      );
      if (albums.isNotEmpty) {
        _allAlbum = albums.first;
        _totalCount = await _allAlbum!.assetCountAsync;
        _usedIndexes.clear();
        _pendingDeletePhotos.clear();
        _history.clear();
        _images.clear();
        await _addRandomBatch();
      }
    } else {
      await PhotoManager.openSetting();
    }
    _isLoading = false;
    notifyListeners();
  }

  // Cargar un batch de fotos aleatorias que no hayan salido
  Future<void> _addRandomBatch() async {
    if (_allAlbum == null || _totalCount == 0) return;
    final availableIndexes = List<int>.generate(_totalCount, (i) => i).where((i) => !_usedIndexes.contains(i)).toList();
    if (availableIndexes.isEmpty) return;
    availableIndexes.shuffle();
    final batchIndexes = availableIndexes.take(_batchSize).toList();
    batchIndexes.sort(); // Para pedir rangos contiguos
    // Agrupar en subrangos contiguos para minimizar llamadas
    List<List<int>> ranges = [];
    for (var idx in batchIndexes) {
      if (ranges.isEmpty || idx != ranges.last.last + 1) {
        ranges.add([idx]);
      } else {
        ranges.last.add(idx);
      }
    }
    List<AssetEntity> batch = [];
    for (var range in ranges) {
      int start = range.first;
      int end = range.last + 1;
      final assets = await _allAlbum!.getAssetListRange(start: start, end: end);
      batch.addAll(assets);
    }
    batch.shuffle(); // Para que el orden siga random
    _images.addAll(batch);
    _usedIndexes.addAll(batchIndexes);
    // Precalcular miniaturas solo para las nuevas
    for (final asset in batch) {
      try {
        final bytes = await asset.thumbnailDataWithSize(const ThumbnailSize(320, 420));
        _thumbnailById[asset.id] = bytes;
      } catch (_) {
        _thumbnailById[asset.id] = null;
      }
    }
    notifyListeners();
  }

  // Llamar esto cuando queden 5 o menos
  Future<void> loadMoreIfNeeded() async {
    if (_images.length <= 5) {
      await _addRandomBatch();
    }
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