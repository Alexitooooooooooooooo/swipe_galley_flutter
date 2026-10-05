import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:photo_manager/photo_manager.dart';

class GalleryProvider with ChangeNotifier {
  static const int _maxThumbnailCache = 80;

  final List<AssetEntity> _images = [];
  final List<AssetEntity> _pendingDeletePhotos = [];
  bool _isLoading = true;
  bool _isBatchLoading = false;
  final Map<String, Uint8List?> _thumbnailById = {};
  final List<_SwipeAction> _history = [];

  // Paginación aleatoria eficiente
  int _totalCount = 0;
  final Set<int> _usedIndexes = {};
  final Set<String> _loadedUniqueIds = {};
  final int _batchSize = 20;
  List<AssetPathEntity> _albums = [];
  AssetPathEntity? _currentAlbum;

  List<AssetEntity> get images => _images;
  List<AssetEntity> get pendingDeletePhotos => _pendingDeletePhotos;
  bool get isLoading => _isLoading;
  bool get isBatchLoading => _isBatchLoading;
  int get totalPhotosInScope => _totalCount;
  int get loadedUniquePhotosCount => _loadedUniqueIds.length;
  bool get hasMorePhotosToLoad => loadedUniquePhotosCount < totalPhotosInScope;
  bool get canUndo => _history.isNotEmpty;
  List<AssetPathEntity> get albums => _albums;
  AssetPathEntity? get currentAlbum => _currentAlbum;

  Uint8List? getThumbnailFor(AssetEntity asset) => _thumbnailById[asset.id];

  GalleryProvider();

  Future<bool> loadImages() async {
    _isLoading = true;
    notifyListeners();
    try {
      final PermissionState ps = await PhotoManager.requestPermissionExtend(
        requestOption: const PermissionRequestOption(
          androidPermission: AndroidPermission(
            type: RequestType.image,
            mediaLocation: false,
          ),
        ),
      );

      final albums = await PhotoManager.getAssetPathList(
        type: RequestType.image,
        hasAll: true,
      );

      final bool hasAccess = ps.hasAccess || albums.isNotEmpty;

      if (hasAccess) {
        _usedIndexes.clear();
        _loadedUniqueIds.clear();
        _pendingDeletePhotos.clear();
        _history.clear();
        _images.clear();
        _thumbnailById.clear();
        _albums = albums;

        if (albums.isNotEmpty) {
          _currentAlbum = albums.first;
          _totalCount = await _currentAlbum!.assetCountAsync;
          await _addRandomBatch();
        } else {
          _currentAlbum = null;
          _totalCount = 0;
        }
      } else {
        _currentAlbum = null;
        _totalCount = 0;
        _images.clear();
        _loadedUniqueIds.clear();
      }
      return hasAccess;
    } catch (e) {
      debugPrint('loadImages error: $e');
      return false;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> setAlbum(AssetPathEntity album) async {
    _isLoading = true;
    notifyListeners();
    try {
      _currentAlbum = album;
      _usedIndexes.clear();
      _loadedUniqueIds.clear();
      // No limpiamos _pendingDeletePhotos para no perder lo ya seleccionado.
      _history.clear();
      _images.clear();
      _thumbnailById.clear();

      _totalCount = await album.assetCountAsync;
      await _addRandomBatch();
    } catch (e) {
      debugPrint('setAlbum error: $e');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  // Cargar un batch de fotos aleatorias que no hayan salido
  Future<void> _addRandomBatch() async {
    if (_isBatchLoading) return;
    if (_currentAlbum == null || _totalCount == 0) return;
    _isBatchLoading = true;
    notifyListeners();
    try {
      final availableIndexes =
          List<int>.generate(_totalCount, (i) => i).where((i) => !_usedIndexes.contains(i)).toList();
      if (availableIndexes.isEmpty) return;

      availableIndexes.shuffle();
      final batchIndexes = availableIndexes.take(_batchSize).toList();
      batchIndexes.sort(); // Para pedir rangos contiguos

      // Agrupar en subrangos contiguos para minimizar llamadas
      final List<List<int>> ranges = [];
      for (final idx in batchIndexes) {
        if (ranges.isEmpty || idx != ranges.last.last + 1) {
          ranges.add([idx]);
        } else {
          ranges.last.add(idx);
        }
      }

      final List<AssetEntity> batch = [];
      final pendingIds = _pendingDeletePhotos.map((p) => p.id).toSet();
      for (final range in ranges) {
        final int start = range.first;
        final int end = range.last + 1;
        var assets = await _currentAlbum!.getAssetListRange(start: start, end: end);
        if (pendingIds.isNotEmpty) {
          assets = assets.where((asset) => !pendingIds.contains(asset.id)).toList();
        }
        batch.addAll(assets);
      }

      batch.shuffle(); // Para que el orden siga random
      _images.addAll(batch);
      _usedIndexes.addAll(batchIndexes);
      _loadedUniqueIds.addAll(batch.map((asset) => asset.id));

      // Precalcular miniaturas solo para las nuevas
      for (final asset in batch) {
        try {
          final bytes = await asset.thumbnailDataWithSize(const ThumbnailSize(320, 420));
          _cacheThumbnail(asset.id, bytes);
        } catch (_) {
          _cacheThumbnail(asset.id, null);
        }
      }
    } catch (e) {
      debugPrint('_addRandomBatch error: $e');
    } finally {
      _isBatchLoading = false;
      notifyListeners();
    }
  }

  // Llamar esto cuando queden 5 o menos
  Future<void> loadMoreIfNeeded() async {
    if (_images.length <= 5 && hasMorePhotosToLoad) {
      await _addRandomBatch();
    }
  }

  Future<void> handleSwipe(int index, bool delete) async {
    final asset = _images[index];
    _history.add(_SwipeAction(asset, delete));
    if (delete) {
      // Solo agregar al array de pendientes si no está ya, para evitar duplicados
      if (!_pendingDeletePhotos.any((a) => a.id == asset.id)) {
        _pendingDeletePhotos.add(asset);
      }
    }
    // Sacar de la lista principal
    _images.removeAt(index);
    _pruneThumbnailCache();
    notifyListeners();
  }

  Future<void> confirmDeleteAll() async {
    if (_pendingDeletePhotos.isEmpty) return;
    try {
      final ids = _pendingDeletePhotos.map((a) => a.id).toList();
      final List<String> result = await PhotoManager.editor.deleteWithIds(ids);
      // Liberar las miniaturas de lo borrado.
      for (final id in ids) {
        _thumbnailById.remove(id);
      }
      if (result.isNotEmpty) {
        debugPrint('Fotos eliminadas exitosamente');
      }
      _pendingDeletePhotos.clear();
      _history.clear(); // Eliminar historial para que no se pueda hacer undo
      notifyListeners();
    } catch (e) {
      debugPrint('Error al borrar: $e');
    }
  }

  void removeFromPending(int index) {
    _pendingDeletePhotos.removeAt(index);
    notifyListeners();
  }

  /// Devuelve la dirección de la acción deshecha: `true` = fue a eliminar
  /// (swipe derecha), `false` = fue conservar (swipe izquierda), `null` = no
  /// había nada que deshacer.
  bool? undoLastAction() {
    if (_history.isEmpty) return null;
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
    return last.delete;
  }

  void _cacheThumbnail(String id, Uint8List? bytes) {
    _thumbnailById[id] = bytes;
    _pruneThumbnailCache();
  }

  /// Evita que el caché de miniaturas crezca sin límite (OOM en galerías
  /// grandes). Primero descarta las que ya no están en la pila visible.
  void _pruneThumbnailCache() {
    if (_thumbnailById.length <= _maxThumbnailCache) return;
    final keep = _images.map((a) => a.id).toSet();
    final removable = _thumbnailById.keys.where((id) => !keep.contains(id)).toList();
    for (final id in removable) {
      if (_thumbnailById.length <= _maxThumbnailCache) break;
      _thumbnailById.remove(id);
    }
  }
}

class _SwipeAction {
  final AssetEntity asset;
  final bool delete;

  _SwipeAction(this.asset, this.delete);
}
