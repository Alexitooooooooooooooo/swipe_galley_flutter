import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:photo_manager/photo_manager.dart';
import '../native_mover.dart';

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
  DateTimeRange? _dateFilter;

  /// Si la app se abrió desde el widget, esta foto debe quedar al frente.
  String? pendingAssetId;

  /// Nombre de álbum que se oculta del feed por defecto (All/Recientes).
  String _hiddenAlbum = '';

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
  DateTimeRange? get dateFilter => _dateFilter;

  Uint8List? getThumbnailFor(AssetEntity asset) => _thumbnailById[asset.id];

  GalleryProvider();

  /// Construye el filtro nativo (por rango de fechas) para photo_manager.
  PMFilter? _buildFilter() {
    final range = _dateFilter;
    if (range == null) return null;
    return FilterOptionGroup(
      createTimeCond: DateTimeCond(
        min: DateTime(range.start.year, range.start.month, range.start.day),
        // Incluye todo el día final.
        max: DateTime(range.end.year, range.end.month, range.end.day, 23, 59, 59, 999),
      ),
    );
  }

  /// Cambia el rango de fechas y recarga la galería. `null` = sin filtro.
  Future<void> setDateFilter(DateTimeRange? range) async {
    _dateFilter = range;
    await loadImages();
  }

  /// Define qué álbum se oculta del feed por defecto (no recarga por sí solo).
  void setHiddenAlbum(String name) {
    _hiddenAlbum = name;
  }

  bool _isHidden(AssetEntity asset) {
    if (_hiddenAlbum.isEmpty) return false;
    final path = asset.relativePath ?? '';
    if (path.isEmpty) return false;
    return path == _hiddenAlbum ||
        path.endsWith('/$_hiddenAlbum') ||
        path.contains('/$_hiddenAlbum/');
  }

  /// Pone la foto [assetId] al frente de la pila (p. ej. al tocar el widget).
  Future<void> bringToFront(String assetId) async {
    final index = _images.indexWhere((a) => a.id == assetId);
    if (index == 0) return;
    if (index > 0) {
      final asset = _images.removeAt(index);
      _images.insert(0, asset);
      notifyListeners();
      return;
    }
    // No está cargada: la traemos por id y la insertamos al frente.
    try {
      final asset = await AssetEntity.fromId(assetId);
      if (asset == null) return;
      try {
        final bytes = await asset.thumbnailDataWithSize(const ThumbnailSize(320, 420));
        _cacheThumbnail(asset.id, bytes);
      } catch (_) {
        // Sin miniatura, se mostrará vacía.
      }
      _images.insert(0, asset);
      notifyListeners();
    } catch (e) {
      debugPrint('bringToFront error: $e');
    }
  }

  Future<bool> loadImages() async {
    _isLoading = true;
    notifyListeners();
    debugPrint('[Gallery] loadImages: inicio');
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
        filterOption: _buildFilter(),
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
          _totalCount =
              await _currentAlbum!.assetCountAsync.timeout(const Duration(seconds: 15));
          await _addRandomBatch();
        } else {
          _currentAlbum = null;
          _totalCount = 0;
        }

        // Si venimos del widget, ponemos esa foto al frente.
        final pending = pendingAssetId;
        pendingAssetId = null;
        if (pending != null) {
          await bringToFront(pending);
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
      debugPrint('[Gallery] loadImages: fin -> ${_images.length} fotos (total=$_totalCount)');
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
        var assets = await _currentAlbum!
            .getAssetListRange(start: start, end: end)
            .timeout(const Duration(seconds: 15));
        if (pendingIds.isNotEmpty) {
          assets = assets.where((asset) => !pendingIds.contains(asset.id)).toList();
        }
        // Ocultar el álbum destino del feed por defecto (solo en "All").
        if (_currentAlbum?.isAll == true && _hiddenAlbum.isNotEmpty) {
          assets = assets.where((asset) => !_isHidden(asset)).toList();
        }
        batch.addAll(assets);
      }

      batch.shuffle(); // Para que el orden siga random
      _images.addAll(batch);
      _usedIndexes.addAll(batchIndexes);
      _loadedUniqueIds.addAll(batch.map((asset) => asset.id));
      notifyListeners(); // Mostrar las fotos de inmediato
      debugPrint('[Gallery] batch: ${batch.length} fotos (pila=${_images.length}, total=$_totalCount)');

      // Precalcular miniaturas en paralelo (por grupos) para no bloquear la UI.
      const int chunkSize = 6;
      for (int i = 0; i < batch.length; i += chunkSize) {
        final int end = (i + chunkSize) > batch.length ? batch.length : i + chunkSize;
        final chunk = batch.sublist(i, end);
        await Future.wait(chunk.map((asset) async {
          try {
            final bytes = await asset
                .thumbnailDataWithSize(const ThumbnailSize(320, 420))
                .timeout(const Duration(seconds: 10));
            _cacheThumbnail(asset.id, bytes);
          } catch (_) {
            _cacheThumbnail(asset.id, null);
          }
        }));
        notifyListeners();
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

  /// Elimina definitivamente las fotos en "A eliminar" y devuelve los bytes
  /// liberados (0 si no se pudo calcular).
  Future<int> confirmDeleteAll() async {
    if (_pendingDeletePhotos.isEmpty) return 0;
    try {
      // Calcular tamaño antes de borrar.
      int bytes = 0;
      for (final asset in _pendingDeletePhotos) {
        try {
          final file = await asset.originFile;
          bytes += await file?.length() ?? 0;
        } catch (_) {
          // Algunas fotos pueden no exponer archivo; se ignora.
        }
      }

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
      return bytes;
    } catch (e) {
      debugPrint('Error al borrar: $e');
      return 0;
    }
  }

  /// Mueve [assets] al álbum indicado (por defecto `swipe-album`).
  ///
  /// En Android usa la carpeta de MediaStore (`Pictures/<album>`); en el resto
  /// de plataformas crea el álbum y copia los assets. Devuelve `true` si se
  /// movieron correctamente. Los assets movidos se quitan de la pila actual.
  Future<bool> moveToAlbum(
    List<AssetEntity> assets, {
    String albumName = 'swipe-album',
  }) async {
    if (assets.isEmpty) return false;
    final ids = assets.map((a) => a.id).toSet();

    // Quitar de la UI de inmediato: la pila avanza sin esperar al sistema.
    _images.removeWhere((a) => ids.contains(a.id));
    _pendingDeletePhotos.removeWhere((a) => ids.contains(a.id));
    _history.removeWhere((h) => ids.contains(h.asset.id));
    for (final id in ids) {
      _thumbnailById.remove(id);
    }
    notifyListeners();

    try {
      bool ok = false;
      final target = 'Pictures/$albumName';
      if (Platform.isAndroid) {
        final ids = assets.map((a) => a.id).toList();
        // Intentamos siempre el move nativo primero: si hay "All files access"
        // funciona sin diálogo. Si no, cae al plugin (que sí pide permiso).
        final nativeOk = await NativeMover.moveToAlbum(ids, target);
        final allFiles = await NativeMover.hasAllFilesAccess();
        debugPrint('[Gallery] move native=$nativeOk allFilesAccess=$allFiles');
        if (nativeOk) {
          ok = true;
        } else {
          ok = await PhotoManager.editor.android.moveAssetsToPath(
            entities: assets,
            targetPath: target,
          );
        }
      } else {
        final pathEntity = await _ensureAlbum(albumName);
        if (pathEntity == null) return false;
        for (final asset in assets) {
          await PhotoManager.editor.copyAssetToPath(asset: asset, pathEntity: pathEntity);
        }
        ok = true;
      }
      debugPrint('[Gallery] moveToAlbum($albumName): $ok (${assets.length})');
      return ok;
    } catch (e) {
      debugPrint('moveToAlbum error: $e');
      return false;
    }
  }

  Future<AssetPathEntity?> _ensureAlbum(String name) async {
    final albums = await PhotoManager.getAssetPathList(type: RequestType.image);
    for (final album in albums) {
      if (album.name == name) return album;
    }
    return PhotoManager.editor.darwin.createAlbum(name);
  }

  void removeFromPending(int index) {
    _pendingDeletePhotos.removeAt(index);
    notifyListeners();
  }  /// Devuelve la dirección de la acción deshecha: `true` = fue a eliminar
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
