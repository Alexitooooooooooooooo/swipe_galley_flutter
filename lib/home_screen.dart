import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:provider/provider.dart';
import 'package:photo_manager/photo_manager.dart';
import 'home_widget_service.dart';
import 'native_mover.dart';
import 'providers/gallery_provider.dart';
import 'providers/settings_provider.dart';
import 'providers/theme_provider.dart';
import 'settings_screen.dart';
import 'theme/app_theme.dart';
import 'widgets/swipe_deck.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({Key? key}) : super(key: key);

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  bool _showDeleteView = false; // Controla si vemos la galería o la vista de "A eliminar"
  final SwipeDeckController _deckController = SwipeDeckController();
  String? _widgetPhotoId;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final provider = context.read<GalleryProvider>();
      // Cargamos si aún no hay fotos. (No condicionamos a isLoading porque el
      // provider arranca en isLoading=true y eso impedía la primera carga.)
      if (provider.images.isEmpty) {
        final ok = await provider.loadImages();
        if (!ok && mounted) {
          _showPermissionDeniedDialog();
        }
      }
    });
  }

  void _showPermissionDeniedDialog() {
    if (!mounted) return;
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Permiso Denegado'),
        content: const Text(
          'No tenemos acceso a tu galería. Habilítalo desde Ajustes de la app para continuar.',
        ),
        actions: [
          TextButton(
            onPressed: () async {
              Navigator.pop(context);
              await PhotoManager.openSetting();
            },
            child: const Text('Abrir ajustes'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cerrar'),
          ),
        ],
      ),
    );
  }

  /// Mantiene el widget sincronizado con la foto que está al frente (o la
  /// limpia si no hay fotos). Se llama en cada build, pero solo actúa cuando
  /// cambia la tarjeta de arriba.
  void _updateWidgetPhoto(GalleryProvider provider) {
    if (provider.images.isEmpty) {
      if (_widgetPhotoId == 'empty') return;
      _widgetPhotoId = 'empty';
      WidgetsBinding.instance.addPostFrameCallback((_) {
        HomeWidgetService.syncPhoto(null);
      });
      return;
    }
    final top = provider.images.first;
    final bytes = provider.getThumbnailFor(top);
    // Espera a que la miniatura esté lista antes de enviarla.
    if (bytes == null) return;
    if (_widgetPhotoId == top.id) return;
    _widgetPhotoId = top.id;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      HomeWidgetService.syncPhoto(bytes, assetId: top.id);
    });
  }

  Widget _buildEmptyState(GalleryProvider provider) {
    final p = AppPalette.of(context);
    final bool hasFilter = provider.dateFilter != null;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppTokens.s24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.photo_library_outlined, size: 48, color: p.textMuted),
            const SizedBox(height: AppTokens.s16),
            Text(
              'No hay fotos para mostrar',
              style: TextStyle(color: p.textPrimary, fontSize: 16, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: AppTokens.s8),
            Text(
              hasFilter
                  ? 'Prueba quitando el filtro de fechas.'
                  : 'No encontramos fotos en esta galería.',
              textAlign: TextAlign.center,
              style: TextStyle(color: p.textMuted, fontSize: 13),
            ),
            const SizedBox(height: AppTokens.s20),
            Wrap(
              spacing: AppTokens.s12,
              runSpacing: AppTokens.s12,
              alignment: WrapAlignment.center,
              children: [
                ElevatedButton.icon(
                  onPressed: () => provider.loadImages(),
                  icon: Icon(Icons.refresh, color: p.ctaFg, size: 18),
                  label: Text('Recargar', style: TextStyle(color: p.ctaFg, fontWeight: FontWeight.w600)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: p.ctaBg,
                    elevation: 0,
                    shape: const StadiumBorder(),
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                  ),
                ),
                if (hasFilter)
                  OutlinedButton(
                    onPressed: () => provider.setDateFilter(null),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: p.textPrimary,
                      side: BorderSide(color: p.hairline, width: 1),
                      shape: const StadiumBorder(),
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                    ),
                    child: const Text('Quitar filtro', style: TextStyle(fontWeight: FontWeight.w600)),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    _deckController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final p = AppPalette.of(context);
    final provider = context.watch<GalleryProvider>();

    _updateWidgetPhoto(provider);

    return Scaffold(
      backgroundColor: p.canvas,
      body: SafeArea(
        child: Column(
          children: [
            const SizedBox(height: AppTokens.s16),
            _buildHeader(context, provider, p),
            const SizedBox(height: AppTokens.s12),
            const _DailyGoalBanner(),
            const SizedBox(height: AppTokens.s12),
            // Contenedor principal: frosted/graphite panel
            Expanded(
              flex: 2,
              child: Container(
                margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4).copyWith(bottom: 12),
                decoration: BoxDecoration(
                  color: p.panel,
                  borderRadius: BorderRadius.circular(AppTokens.radiusCard),
                  border: Border.all(color: p.hairline, width: 1),
                ),
                child: Column(
                  children: [
                    // Segmented pill tabs (Galería / A eliminar)
                    Padding(
                      padding: const EdgeInsets.all(AppTokens.s16),
                      child: Row(
                        children: [
                          Expanded(
                            child: _SegmentPill(
                              label: 'Galería',
                              active: !_showDeleteView,
                              enabled: true,
                              onTap: () {
                                setState(() {
                                  _showDeleteView = false;
                                });
                              },
                            ),
                          ),
                          const SizedBox(width: AppTokens.s8),
                          Expanded(
                            child: _SegmentPill(
                              label: 'A eliminar (${provider.pendingDeletePhotos.length})',
                              active: _showDeleteView && provider.pendingDeletePhotos.isNotEmpty,
                              enabled: provider.pendingDeletePhotos.isNotEmpty,
                              onTap: () {
                                setState(() {
                                  _showDeleteView = true;
                                });
                              },
                            ),
                          ),
                        ],
                      ),
                    ),
                    // Área del Swiper y las Fotos
                    Expanded(
                      child: _showDeleteView
                          ? _buildDeleteGallery(provider)
                          : provider.images.isNotEmpty
                              ? _buildSwiperArea(provider)
                              : (provider.isLoading ||
                                      provider.isBatchLoading ||
                                      provider.hasMorePhotosToLoad)
                                  ? Center(child: CircularProgressIndicator(color: p.textPrimary))
                                  : _buildEmptyState(provider),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context, GalleryProvider provider, AppPalette p) {
    final themeProvider = context.watch<ThemeProvider>();
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppTokens.s16),
      child: Row(
        children: [
          // Title logo on an inverted (snow) surface so it reads on dark canvas
          Container(
            height: 48,
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            decoration: BoxDecoration(
              color: AppTokens.snowWhite,
              borderRadius: BorderRadius.circular(AppTokens.radiusUi),
              border: Border.all(color: p.hairline, width: 1),
            ),
            child: Image.asset(
              'assets/titulo.png',
              fit: BoxFit.contain,
              errorBuilder: (context, error, stackTrace) => const Text(
                'SWIPE\nGALLERY',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w800,
                  color: AppTokens.graphite,
                  height: 1.0,
                ),
              ),
            ),
          ),
          const Spacer(),
          _GhostIconButton(
            icon: themeProvider.isDark ? Icons.light_mode_outlined : Icons.dark_mode_outlined,
            tooltip: themeProvider.isDark ? 'Modo claro' : 'Modo oscuro',
            onTap: themeProvider.toggle,
          ),
          const SizedBox(width: AppTokens.s8),
          _GhostIconButton(
            icon: Icons.tune,
            tooltip: 'Seleccionar Álbum',
            onTap: () => _showAlbumSelectionModal(context, provider),
          ),
          const SizedBox(width: AppTokens.s8),
          _GhostIconButton(
            icon: Icons.settings_outlined,
            tooltip: 'Configuración',
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => const SettingsScreen()),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSwiperArea(GalleryProvider provider) {
    final p = AppPalette.of(context);

    if (provider.images.isEmpty && (provider.isBatchLoading || provider.hasMorePhotosToLoad)) {
      return Center(child: CircularProgressIndicator(color: p.textPrimary));
    }
    if (provider.images.isEmpty) {
      return Center(child: Text('No hay fotos disponibles', style: TextStyle(color: p.textSecondary)));
    }

    if (provider.images.length == 5) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) provider.loadMoreIfNeeded();
      });
    }

    return Column(
      children: [
        Expanded(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppTokens.s12, vertical: AppTokens.s8),
            child: SwipeDeck<AssetEntity>(
              controller: _deckController,
              items: provider.images,
              onSwipe: (asset, direction) => _handleDeckSwipe(provider, direction),
              itemBuilder: (context, asset, isTop, progress) =>
                  _buildSwipeCard(provider, asset, isTop),
            ),
          ),
        ),
        const SizedBox(height: AppTokens.s12),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            // Deshacer
            _RoundActionButton(
              color: p.panelFrost,
              borderColor: p.hairline,
              icon: Icons.undo,
              iconColor: p.textSecondary,
              enabled: provider.canUndo,
              onTap: () {
                final bool? wasDelete = provider.undoLastAction();
                if (wasDelete != null) {
                  _deckController.playEnter(
                    wasDelete ? SwipeDirection.right : SwipeDirection.left,
                  );
                }
                setState(() {});
              },
            ),
            // Enviar a "A eliminar" (swipe a la derecha)
            _RoundActionButton(
              color: p.danger,
              icon: Icons.close,
              iconColor: Colors.white,
              iconSize: 32,
              onTap: () => _deckController.swipeRight(),
            ),
            // Conservar (swipe a la izquierda)
            _RoundActionButton(
              color: p.ctaBg,
              icon: Icons.check,
              iconColor: p.ctaFg,
              iconSize: 32,
              onTap: () => _deckController.swipeLeft(),
            ),
          ],
        ),
        const SizedBox(height: AppTokens.s12),
      ],
    );
  }

  void _handleDeckSwipe(GalleryProvider provider, SwipeDirection direction) {
    final settings = context.read<SettingsProvider>();
    final bool isUp = direction == SwipeDirection.up;
    final bool shouldDelete = direction == SwipeDirection.right;

    if (settings.hapticsEnabled) {
      (shouldDelete || isUp) ? HapticFeedback.mediumImpact() : HapticFeedback.selectionClick();
    }
    if (settings.soundEnabled) {
      SystemSound.play(SystemSoundType.click);
    }
    settings.recordSwipe();

    if (isUp) {
      _moveCurrentUp(provider, settings);
      setState(() {});
      return;
    }

    provider.handleSwipe(0, shouldDelete);
    setState(() {});
    if (shouldDelete) {
      _checkDeleteLimit(provider);
    }
    if (provider.images.length == 5) {
      provider.loadMoreIfNeeded();
    }
  }

  Future<void> _moveCurrentUp(GalleryProvider provider, SettingsProvider settings) async {
    if (provider.images.isEmpty) return;
    final asset = provider.images.first;
    final bool hasAccess = Platform.isAndroid ? await NativeMover.hasAllFilesAccess() : true;
    final ok = await provider.moveToAlbum([asset], albumName: settings.moveAlbum);
    if (!mounted) return;
    final messenger = ScaffoldMessenger.of(context);
    messenger.hideCurrentSnackBar();
    messenger.showSnackBar(
      SnackBar(
        content: Text(ok ? 'Movida a «${settings.moveAlbum}»' : 'No se pudo mover'),
        duration: const Duration(seconds: 3),
        action: (!hasAccess && Platform.isAndroid)
            ? SnackBarAction(
                label: 'Sin permiso diario',
                onPressed: () => Permission.manageExternalStorage.request(),
              )
            : null,
      ),
    );
  }

  Future<void> _movePendingToAlbum(GalleryProvider provider) async {
    if (provider.pendingDeletePhotos.isEmpty) return;
    final settings = context.read<SettingsProvider>();
    final assets = List<AssetEntity>.from(provider.pendingDeletePhotos);
    final n = assets.length;
    final ok = await provider.moveToAlbum(assets, albumName: settings.moveAlbum);
    if (!mounted) return;
    setState(() {
      _showDeleteView = false;
    });
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(ok ? 'Movidas $n a «${settings.moveAlbum}»' : 'No se pudieron mover'),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  static const List<String> _monthsEs = [
    'enero',
    'febrero',
    'marzo',
    'abril',
    'mayo',
    'junio',
    'julio',
    'agosto',
    'septiembre',
    'octubre',
    'noviembre',
    'diciembre',
  ];

  String _formatDateLong(DateTime d) {
    final month = _monthsEs[(d.month - 1).clamp(0, 11)];
    return '${d.day} de $month ${d.year}';
  }

  Widget _buildSwipeCard(GalleryProvider provider, AssetEntity asset, bool isTop) {
    final p = AppPalette.of(context);
    final bytes = provider.getThumbnailFor(asset);

    String assetLabel = asset.title ?? asset.id;
    String assetPath = asset.relativePath ?? '';
    final DateTime assetDateTime = asset.createDateTime;
    String assetDateLong = _formatDateLong(assetDateTime);
    String assetDateIso =
        '${assetDateTime.year}-${assetDateTime.month.toString().padLeft(2, '0')}-${assetDateTime.day.toString().padLeft(2, '0')}';

    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(AppTokens.radiusCard),
        border: Border.all(color: p.hairline, width: 1),
        color: p.isDark ? const Color(0xFF1E1E1E) : const Color(0xFFEAEAEA),
      ),
      clipBehavior: Clip.antiAlias,
      child: Stack(
        fit: StackFit.expand,
        children: [
          if (bytes != null)
            _ZoomableImage(bytes: bytes, enabled: isTop),
          if (bytes == null && isTop)
            Center(
              child: SizedBox(
                width: 26,
                height: 26,
                child: CircularProgressIndicator(strokeWidth: 2, color: p.textSecondary),
              ),
            ),
          if (isTop)
            Positioned(
              top: 10,
              right: 10,
              child: Material(
                color: p.panelFrost,
                shape: CircleBorder(side: BorderSide(color: p.hairline, width: 1)),
                clipBehavior: Clip.antiAlias,
                child: IconButton(
                  icon: Icon(Icons.info_outline, color: p.textPrimary, size: 24),
                  tooltip: 'Ver metadata',
                  onPressed: () =>
                      _showMetadataDialog(context, assetLabel, assetPath, assetDateLong, assetDateIso),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildDeleteGallery(GalleryProvider provider) {
    final p = AppPalette.of(context);
    final pending = provider.pendingDeletePhotos;
    if (pending.isEmpty) {
      return Center(child: Text('No hay fotos marcadas para eliminar', style: TextStyle(color: p.textSecondary)));
    }

    return Column(
      children: [
        Expanded(
          child: GridView.builder(
            padding: const EdgeInsets.all(AppTokens.s16),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 3,
              crossAxisSpacing: 8,
              mainAxisSpacing: 8,
            ),
            itemCount: pending.length,
            itemBuilder: (context, index) {
              final asset = pending[index];
              return Stack(
                children: [
                  Positioned.fill(
                    child: FutureBuilder(
                      future: asset.thumbnailDataWithSize(const ThumbnailSize(200, 200)),
                      builder: (context, snapshot) {
                        if (snapshot.connectionState == ConnectionState.done && snapshot.hasData) {
                          return ClipRRect(
                            borderRadius: BorderRadius.circular(AppTokens.radiusUi),
                            child: Image.memory(snapshot.data!, fit: BoxFit.cover),
                          );
                        }
                        return Container(
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(AppTokens.radiusUi),
                            color: p.panelFrost,
                          ),
                        );
                      },
                    ),
                  ),
                  Positioned(
                    top: 4,
                    right: 4,
                    child: GestureDetector(
                      onTap: () => provider.removeFromPending(index),
                      child: Container(
                        width: 24,
                        height: 24,
                        decoration: BoxDecoration(
                          color: Colors.black.withValues(alpha: 0.6),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.close, color: Colors.white, size: 16),
                      ),
                    ),
                  ),
                ],
              );
            },
          ),
        ),
        Padding(
          padding: const EdgeInsets.all(AppTokens.s16),
          child: Column(
            children: [
              SizedBox(
                width: double.infinity,
                height: 52,
                child: OutlinedButton.icon(
                  onPressed: () => _movePendingToAlbum(provider),
                  icon: Icon(Icons.drive_file_move_outline, color: p.textPrimary, size: 22),
                  label: Text(
                    'Mover a álbum',
                    style: TextStyle(color: p.textPrimary, fontSize: 16, fontWeight: FontWeight.w600),
                  ),
                  style: OutlinedButton.styleFrom(
                    side: BorderSide(color: p.hairline, width: 1),
                    shape: const StadiumBorder(),
                  ),
                ),
              ),
              const SizedBox(height: AppTokens.s12),
              SizedBox(
                width: double.infinity,
                height: 52,
                child: ElevatedButton.icon(
                  onPressed: () => _showConfirmDeleteDialog(context, provider),
                  icon: const Icon(Icons.delete_outline, color: Colors.white, size: 22),
                  label: const Text(
                    'Eliminar',
                    style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w600),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: p.danger,
                    elevation: 0,
                    shape: const StadiumBorder(),
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  void _showMetadataDialog(
    BuildContext context,
    String label,
    String path,
    String dateLong,
    String dateIso,
  ) {
    final p = AppPalette.of(context);
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(
          'Información de la foto',
          textAlign: TextAlign.center,
          style: TextStyle(fontWeight: FontWeight.w600, fontSize: 18, color: p.textPrimary),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Nombre: $label', style: TextStyle(fontSize: 15, color: p.textPrimary)),
            const SizedBox(height: 6),
            Text('Ubicación: $path', style: TextStyle(fontSize: 15, color: p.textPrimary)),
            const SizedBox(height: 6),
            Text('Fecha: $dateLong', style: TextStyle(fontSize: 15, color: p.textPrimary)),
            const SizedBox(height: 2),
            Padding(
              padding: const EdgeInsets.only(left: 48),
              child: Text('($dateIso)', style: TextStyle(fontSize: 13, color: p.textMuted)),
            ),
          ],
        ),
        actionsAlignment: MainAxisAlignment.center,
        actions: [
          SizedBox(
            width: double.infinity,
            height: 48,
            child: ElevatedButton(
              onPressed: () => Navigator.pop(context),
              style: ElevatedButton.styleFrom(
                backgroundColor: p.ctaBg,
                foregroundColor: p.ctaFg,
                elevation: 0,
                shape: const StadiumBorder(),
              ),
              child: Text('Cerrar', style: TextStyle(color: p.ctaFg, fontWeight: FontWeight.w600, fontSize: 15)),
            ),
          ),
        ],
      ),
    );
  }

  void _showConfirmDeleteDialog(BuildContext context, GalleryProvider provider) {
    final p = AppPalette.of(context);
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(
          'Eliminar',
          textAlign: TextAlign.center,
          style: TextStyle(fontWeight: FontWeight.w600, fontSize: 18, color: p.textPrimary),
        ),
        content: Text(
          '¿Eliminar ${provider.pendingDeletePhotos.length} elementos seleccionados? Esta acción no se puede deshacer.',
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 15, color: p.textSecondary, height: 1.35),
        ),
        actionsPadding: const EdgeInsets.only(left: 20, right: 20, bottom: 20),
        actions: [
          Row(
            children: [
              Expanded(
                child: SizedBox(
                  height: 50,
                  child: OutlinedButton(
                    onPressed: () => Navigator.pop(context),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: p.textPrimary,
                      side: BorderSide(color: p.hairline, width: 1),
                      shape: const StadiumBorder(),
                    ),
                    child: const Text('Cancelar', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
                  ),
                ),
              ),
              const SizedBox(width: AppTokens.s12),
              Expanded(
                child: SizedBox(
                  height: 50,
                  child: ElevatedButton.icon(
                    onPressed: () async {
                      final settings = context.read<SettingsProvider>();
                      final count = provider.pendingDeletePhotos.length;
                      Navigator.pop(context);
                      final int bytes = await provider.confirmDeleteAll();
                      await settings.recordDeletion(count: count, bytes: bytes);
                      if (mounted) {
                        setState(() {
                          _showDeleteView = false;
                        });
                      }
                    },
                    icon: const Icon(Icons.delete_outline, color: Colors.white, size: 20),
                    label: const Text(
                      'Eliminar',
                      style: TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.w600),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: p.danger,
                      elevation: 0,
                      shape: const StadiumBorder(),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  void _checkDeleteLimit(GalleryProvider provider) {
    final p = AppPalette.of(context);
    if (provider.pendingDeletePhotos.length == 30) {
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: Text(
            'Aviso de rendimiento',
            textAlign: TextAlign.center,
            style: TextStyle(fontWeight: FontWeight.w600, fontSize: 18, color: p.textPrimary),
          ),
          content: Text(
            'Se recomienda ir a la papelera y eliminar las fotos definitivamente para mantener un rendimiento óptimo en la aplicación.',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 15, color: p.textSecondary, height: 1.35),
          ),
          actionsPadding: const EdgeInsets.only(left: 20, right: 20, bottom: 20),
          actions: [
            SizedBox(
              width: double.infinity,
              height: 48,
              child: ElevatedButton(
                onPressed: () => Navigator.pop(context),
                style: ElevatedButton.styleFrom(
                  backgroundColor: p.ctaBg,
                  foregroundColor: p.ctaFg,
                  elevation: 0,
                  shape: const StadiumBorder(),
                ),
                child: Text('Continuar', style: TextStyle(color: p.ctaFg, fontWeight: FontWeight.w600, fontSize: 15)),
              ),
            ),
          ],
        ),
      );
    }
  }

  void _showAlbumSelectionModal(BuildContext context, GalleryProvider provider) {
    final p = AppPalette.of(context);
    showModalBottomSheet(
      context: context,
      backgroundColor: p.panel,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(AppTokens.radiusPanel)),
      ),
      builder: (context) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Padding(
                padding: const EdgeInsets.all(AppTokens.s16),
                child: Text(
                  'Seleccionar Álbum',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600, color: p.textPrimary),
                ),
              ),
              Container(height: 1, color: p.hairline),
              Flexible(
                child: provider.albums.isEmpty
                    ? Padding(
                        padding: const EdgeInsets.all(AppTokens.s32),
                        child: Text('No hay álbumes disponibles', style: TextStyle(color: p.textSecondary)),
                      )
                    : ListView.builder(
                        shrinkWrap: true,
                        itemCount: provider.albums.length,
                        itemBuilder: (context, index) {
                          final album = provider.albums[index];
                          final isSelected = album.id == provider.currentAlbum?.id;
                          return ListTile(
                            title: FutureBuilder<int>(
                              future: album.assetCountAsync,
                              builder: (context, snapshot) {
                                final count = snapshot.data ?? 0;
                                return Text(
                                  '${album.name} ($count)',
                                  style: TextStyle(
                                    color: isSelected ? p.textPrimary : p.textSecondary,
                                    fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
                                    fontSize: 16,
                                  ),
                                );
                              },
                            ),
                            trailing: isSelected
                                ? Icon(Icons.check_circle, color: p.accent)
                                : null,
                            onTap: () {
                              provider.setAlbum(album);
                              Navigator.pop(context);
                            },
                          );
                        },
                      ),
              ),
              const SizedBox(height: AppTokens.s8),
            ],
          ),
        );
      },
    );
  }
}

class _SegmentPill extends StatelessWidget {
  final String label;
  final bool active;
  final bool enabled;
  final VoidCallback? onTap;

  const _SegmentPill({
    required this.label,
    required this.active,
    required this.enabled,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final p = AppPalette.of(context);
    final Color fg = !enabled ? p.textMuted : (active ? p.ctaFg : p.textSecondary);
    return GestureDetector(
      onTap: enabled ? onTap : null,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        alignment: Alignment.center,
        padding: const EdgeInsets.symmetric(vertical: AppTokens.s12),
        decoration: BoxDecoration(
          color: active ? p.ctaBg : Colors.transparent,
          borderRadius: BorderRadius.circular(AppTokens.radiusButton),
          border: Border.all(color: active ? Colors.transparent : p.hairline, width: 1),
        ),
        child: Text(
          label,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(color: fg, fontWeight: FontWeight.w600, fontSize: 15),
        ),
      ),
    );
  }
}

class _RoundActionButton extends StatelessWidget {
  final Color color;
  final Color? borderColor;
  final IconData icon;
  final Color iconColor;
  final double iconSize;
  final VoidCallback onTap;
  final bool enabled;

  const _RoundActionButton({
    required this.color,
    required this.icon,
    required this.iconColor,
    required this.onTap,
    this.borderColor,
    this.iconSize = 28,
    this.enabled = true,
  });

  @override
  Widget build(BuildContext context) {
    final button = Container(
      width: 64,
      height: 64,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: color,
        border: borderColor != null ? Border.all(color: borderColor!, width: 1) : null,
      ),
      child: Icon(icon, color: iconColor, size: iconSize),
    );

    return GestureDetector(
      onTap: enabled ? onTap : null,
      child: AnimatedOpacity(
        opacity: enabled ? 1.0 : 0.3,
        duration: const Duration(milliseconds: 180),
        child: button,
      ),
    );
  }
}

class _GhostIconButton extends StatelessWidget {
  final IconData icon;
  final String tooltip;
  final VoidCallback onTap;

  const _GhostIconButton({
    required this.icon,
    required this.tooltip,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final p = AppPalette.of(context);
    return Material(
      color: p.panelFrost,
      shape: CircleBorder(side: BorderSide(color: p.hairline, width: 1)),
      clipBehavior: Clip.antiAlias,
      child: IconButton(
        icon: Icon(icon, color: p.textPrimary, size: 22),
        tooltip: tooltip,
        onPressed: onTap,
      ),
    );
  }
}

/// Imagen que se agranda (lupa) mientras mantienes presionada la tarjeta.
class _ZoomableImage extends StatefulWidget {
  final Uint8List bytes;
  final bool enabled;

  const _ZoomableImage({required this.bytes, required this.enabled});

  @override
  State<_ZoomableImage> createState() => _ZoomableImageState();
}

class _ZoomableImageState extends State<_ZoomableImage> {
  bool _zoomed = false;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onLongPressStart: widget.enabled ? (_) => setState(() => _zoomed = true) : null,
      onLongPressEnd: widget.enabled ? (_) => setState(() => _zoomed = false) : null,
      onLongPressCancel: widget.enabled ? () => setState(() => _zoomed = false) : null,
      child: AnimatedScale(
        scale: _zoomed ? 1.8 : 1.0,
        duration: const Duration(milliseconds: 220),
        curve: Curves.easeOut,
        child: Image.memory(
          widget.bytes,
          fit: BoxFit.contain,
          gaplessPlayback: true,
        ),
      ),
    );
  }
}

/// Banner de meta diaria: "Revisa N fotos hoy".
class _DailyGoalBanner extends StatelessWidget {
  const _DailyGoalBanner();

  @override
  Widget build(BuildContext context) {
    final p = AppPalette.of(context);
    final settings = context.watch<SettingsProvider>();
    final done = settings.goalReached;
    final text = done
        ? '¡Meta del día cumplida!'
        : 'Revisa ${settings.dailyGoal} fotos hoy';

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: AppTokens.s16),
      padding: const EdgeInsets.symmetric(horizontal: AppTokens.s16, vertical: AppTokens.s12),
      decoration: BoxDecoration(
        color: p.panel,
        borderRadius: BorderRadius.circular(AppTokens.radiusCard),
        border: Border.all(color: p.hairline, width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                done ? Icons.check_circle_outline : Icons.wb_sunny_outlined,
                color: p.textPrimary,
                size: 20,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  text,
                  style: TextStyle(color: p.textPrimary, fontSize: 15, fontWeight: FontWeight.w500),
                ),
              ),
              Text(
                '${settings.reviewedToday}/${settings.dailyGoal}',
                style: TextStyle(color: p.textMuted, fontSize: 13, fontWeight: FontWeight.w600),
              ),
            ],
          ),
          const SizedBox(height: AppTokens.s8),
          ClipRRect(
            borderRadius: BorderRadius.circular(AppTokens.radiusButton),
            child: LinearProgressIndicator(
              value: settings.dailyProgress,
              minHeight: 6,
              backgroundColor: p.hairline,
              valueColor: AlwaysStoppedAnimation<Color>(p.ctaBg),
            ),
          ),
        ],
      ),
    );
  }
}
