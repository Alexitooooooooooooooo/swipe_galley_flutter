import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:flutter_card_swiper/flutter_card_swiper.dart';
import 'providers/gallery_provider.dart';
import 'package:photo_manager/photo_manager.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({Key? key}) : super(key: key);

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final CardSwiperController controller = CardSwiperController();
  int deletedCount = 0; // Contabiliza las veces que se desliza a la izquierda (A eliminar)
  bool _showDeleteView = false; // Controla si vemos la galería o la vista de "A eliminar"
  int _currentIndex = 0; // Índice de la carta que debe ser visible

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<GalleryProvider>().loadImages();
    });
  }

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Escuchar el provider
    final provider = context.watch<GalleryProvider>();

    return Scaffold(
      backgroundColor: const Color(0xFFF5F6F8), // Fondo principal gris claro
      body: SafeArea(
        child: Column(
          children: [
            const SizedBox(height: 16),
            // Logo superior y botón de ajustes
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0),
              child: SizedBox(
                width: double.infinity,
                height: 48,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    Image.asset(
                      'assets/titulo.png',
                      height: 48,
                      fit: BoxFit.contain,
                      errorBuilder: (context, error, stackTrace) => const Text(
                        'SWIPE\nGALERY',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w900,
                          color: Color(0xFF7B2FF2),
                          height: 1.0,
                        ),
                      ),
                    ),
                    Positioned(
                      right: 0,
                      child: Container(
                        decoration: BoxDecoration(
                          color: Colors.white,
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.05),
                              blurRadius: 5,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: IconButton(
                          icon: const Icon(Icons.tune, color: Color(0xFF7B2FF2), size: 24),
                          tooltip: 'Seleccionar Álbum',
                          onPressed: () => _showAlbumSelectionModal(context, provider),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            // Contenedor principal estilo tarjeta (blanco con sombra)
            Expanded(
              flex: 2, // Hacer el área más grande
              child: Container(
                margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4).copyWith(bottom: 12), // Menos margen
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(24),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.05),
                      blurRadius: 10,
                      offset: const Offset(0, 5),
                    ),
                  ],
                ),
                child: Column(
                  children: [
                    // Fila superior (Galería / A eliminar)
                    Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          GestureDetector(
                            onTap: () {
                              setState(() {
                                _showDeleteView = false;
                                _currentIndex = 0; // Al volver a galería, mostrar siempre la primera
                              });
                            },
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                              decoration: BoxDecoration(
                                color: !_showDeleteView ? const Color(0xFF9047FF) : const Color(0xFFF0F0F0),
                                borderRadius: BorderRadius.circular(24),
                              ),
                              child: Text(
                                'Galería',
                                style: TextStyle(
                                  color: !_showDeleteView ? Colors.white : Colors.grey[700],
                                  fontWeight: FontWeight.bold,
                                  fontSize: 16,
                                ),
                              ),
                            ),
                          ),
                          Builder(
                            builder: (context) {
                              final pending = provider.pendingDeletePhotos;
                              final enabled = pending.isNotEmpty;
                              final bool isActive = _showDeleteView && enabled;
                              return GestureDetector(
                                onTap: enabled
                                    ? () {
                                        setState(() {
                                          _showDeleteView = true;
                                        });
                                      }
                                    : null,
                                child: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                                  decoration: BoxDecoration(
                                    color: !enabled
                                        ? const Color(0xFFF0F0F0)
                                        : (isActive ? const Color(0xFFFF4D4D) : const Color(0xFFFFE5E5)),
                                    borderRadius: BorderRadius.circular(24),
                                  ),
                                  child: Text(
                                    'A eliminar (${pending.length})',
                                    style: TextStyle(
                                      color: !enabled
                                          ? Colors.grey
                                          : (isActive ? Colors.white : const Color(0xFFCC0000)),
                                      fontWeight: FontWeight.w600,
                                      fontSize: 16,
                                    ),
                                  ),
                                ),
                              );
                            },
                          ),
                        ],
                      ),
                    ),
                    // Área del Swiper y las Fotos
                    Expanded(
                      child: provider.isLoading
                          ? const Center(child: CircularProgressIndicator())
                          : _showDeleteView
                              ? _buildDeleteGallery(provider)
                              : provider.images.isEmpty
                                  ? const Center(
                                      child: Text(
                                        '¡No hay más fotos!',
                                        style: TextStyle(color: Colors.black54, fontSize: 16),
                                      ),
                                    )
                                  : _buildSwiperArea(provider),
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

  Widget _buildSwiperArea(GalleryProvider provider) {
    if (provider.images.isEmpty) {
      return const Center(
        child: Text('No hay fotos disponibles'),
      );
    }
    final asset = provider.images.first;
    final bytes = provider.getThumbnailFor(asset);

    // Cargar más si quedan 5 o menos
    if (provider.images.length <= 5) {
      provider.loadMoreIfNeeded();
    }

    // Metadata de la imagen
    String assetLabel = asset.title ?? asset.id;
    String assetPath = asset.relativePath ?? '';
    String assetDate = asset.createDateTime != null
        ? '${asset.createDateTime.year}-${asset.createDateTime.month.toString().padLeft(2, '0')}-${asset.createDateTime.day.toString().padLeft(2, '0')}'
        : '';

    return Column(
      children: [
        Expanded(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 8.0),
            child: LayoutBuilder(
              builder: (context, constraints) {
                final cardWidth = constraints.maxWidth;
                final cardHeight = constraints.maxHeight;
                return Dismissible(
                  key: ValueKey('dismiss-' + asset.id),
                  direction: DismissDirection.horizontal,
                  onDismissed: (direction) async {
                    final shouldDelete = direction == DismissDirection.startToEnd; // hacia la derecha
                    if (shouldDelete) {
                      setState(() {
                        deletedCount++;
                      });
                    }
                    await provider.handleSwipe(0, shouldDelete);
                    setState(() {});
                    if (shouldDelete) {
                      _checkDeleteLimit(provider);
                    }
                    // Cargar más si quedan 5 o menos después del swipe
                    if (provider.images.length <= 5) {
                      await provider.loadMoreIfNeeded();
                      setState(() {});
                    }
                  },
                  background: ClipRRect(
                    borderRadius: BorderRadius.circular(24),
                    child: Container(
                      alignment: Alignment.centerLeft,
                      padding: const EdgeInsets.only(left: 24),
                      color: const Color(0xFFFF4D4D),
                      child: const Icon(Icons.close, color: Colors.white, size: 32),
                    ),
                  ),
                  secondaryBackground: ClipRRect(
                    borderRadius: BorderRadius.circular(24),
                    child: Container(
                      alignment: Alignment.centerRight,
                      padding: const EdgeInsets.only(right: 24),
                      color: const Color(0xFF7B2FF2),
                      child: const Icon(Icons.check, color: Colors.white, size: 32),
                    ),
                  ),
                  child: Container(
                    width: cardWidth,
                    height: cardHeight,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(24),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.08),
                          blurRadius: 10,
                          offset: const Offset(0, 6),
                        ),
                      ],
                    ),
                    child: Stack(
                      children: [
                        Positioned.fill(
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(24),
                            child: TweenAnimationBuilder<double>(
                              key: ValueKey('fade-' + asset.id),
                              tween: Tween(begin: 0, end: 1),
                              duration: const Duration(milliseconds: 220),
                              builder: (context, value, child) => Opacity(
                                opacity: value,
                                child: child,
                              ),
                              child: bytes != null
                                  ? Container(
                                      color: Colors.grey[200], // Fondo para fotos no cuadradas
                                      child: Image.memory(
                                        bytes,
                                        fit: BoxFit.contain,
                                        gaplessPlayback: true,
                                      ),
                                    )
                                  : Container(color: Colors.grey[300]),
                            ),
                          ),
                        ),
                        Positioned(
                          top: 10,
                          right: 10,
                          child: Container(
                            decoration: const BoxDecoration(
                              color: Colors.white,
                              shape: BoxShape.circle,
                            ),
                            child: IconButton(
                              icon: const Icon(Icons.info_outline, color: Color(0xFF7B2FF2), size: 28),
                              tooltip: 'Ver metadata',
                              onPressed: () {
                                showDialog(
                                  context: context,
                                  builder: (context) => AlertDialog(
                                    backgroundColor: Colors.white,
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(24),
                                    ),
                                    title: const Text(
                                      'Información de la foto',
                                      textAlign: TextAlign.center,
                                      style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 18,
                                        color: Color(0xFF7B2FF2),
                                      ),
                                    ),
                                    content: Column(
                                      mainAxisSize: MainAxisSize.min,
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          'Nombre: $assetLabel',
                                          style: const TextStyle(fontSize: 15, color: Colors.black),
                                        ),
                                        const SizedBox(height: 6),
                                        Text(
                                          'Ubicación: $assetPath',
                                          style: const TextStyle(fontSize: 15, color: Colors.black),
                                        ),
                                        const SizedBox(height: 6),
                                        Text(
                                          'Fecha: $assetDate',
                                          style: const TextStyle(fontSize: 15, color: Colors.black),
                                        ),
                                      ],
                                    ),
                                    actionsAlignment: MainAxisAlignment.center,
                                    actions: [
                                      ElevatedButton(
                                        onPressed: () => Navigator.pop(context),
                                        style: ElevatedButton.styleFrom(
                                          backgroundColor: const Color(0xFF7B2FF2),
                                          shape: RoundedRectangleBorder(
                                            borderRadius: BorderRadius.circular(24),
                                          ),
                                          padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 12),
                                          elevation: 0,
                                        ),
                                        child: const Text(
                                          'Cerrar',
                                          style: TextStyle(
                                            color: Colors.white,
                                            fontWeight: FontWeight.bold,
                                            fontSize: 16,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                );
                              },
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        ),
        const SizedBox(height: 12),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            // Botón de deshacer
            GestureDetector(
              onTap: () {
                final provider = context.read<GalleryProvider>();
                provider.undoLastAction();
                setState(() {});
              },
              child: Container(
                width: 70,
                height: 70,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.black.withOpacity(0.05),
                  border: Border.all(color: Colors.black.withOpacity(0.1), width: 1.5),
                ),
                child: const Icon(Icons.undo, color: Colors.black87, size: 28),
              ),
            ),
            // Enviar a "A eliminar"
            GestureDetector(
              onTap: () async {
                if (provider.images.isEmpty) return;
                await provider.handleSwipe(0, true);
                setState(() {
                  deletedCount++;
                });
                _checkDeleteLimit(provider);
                if (provider.images.length <= 5) {
                  await provider.loadMoreIfNeeded();
                  setState(() {});
                }
              },
              child: Container(
                width: 70,
                height: 70,
                decoration: const BoxDecoration(
                  shape: BoxShape.circle,
                  color: Color(0xFFFF4D4D),
                ),
                child: const Icon(Icons.close, color: Colors.white, size: 36),
              ),
            ),
            // Conservar
            GestureDetector(
              onTap: () async {
                if (provider.images.isEmpty) return;
                await provider.handleSwipe(0, false);
                setState(() {});
                if (provider.images.length <= 5) {
                  await provider.loadMoreIfNeeded();
                  setState(() {});
                }
              },
              child: Container(
                width: 70,
                height: 70,
                decoration: const BoxDecoration(
                  shape: BoxShape.circle,
                  color: Color(0xFF7B2FF2),
                ),
                child: const Icon(Icons.check, color: Colors.white, size: 36),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
      ],
    );
  }

  Widget _buildDeleteGallery(GalleryProvider provider) {
    final pending = provider.pendingDeletePhotos;
    if (pending.isEmpty) {
      return const Center(child: Text('No hay fotos marcadas para eliminar'));
    }

    return Column(
      children: [
        Expanded(
          child: GridView.builder(
            padding: const EdgeInsets.all(16),
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
                      future: asset.thumbnailDataWithSize(ThumbnailSize(200, 200)),
                      builder: (context, snapshot) {
                        if (snapshot.connectionState == ConnectionState.done && snapshot.hasData) {
                          return ClipRRect(
                            borderRadius: BorderRadius.circular(12),
                            child: Image.memory(
                              snapshot.data!,
                              fit: BoxFit.cover,
                            ),
                          );
                        }
                        return Container(
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(12),
                            color: Colors.grey[200],
                          ),
                        );
                      },
                    ),
                  ),
                  Positioned(
                    top: 4,
                    right: 4,
                    child: GestureDetector
                    (
                      onTap: () {
                        provider.removeFromPending(index);
                      },
                      child: Container(
                        width: 24,
                        height: 24,
                        decoration: BoxDecoration(
                          color: Colors.black.withOpacity(0.6),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.close,
                          color: Colors.white,
                          size: 16,
                        ),
                      ),
                    ),
                  ),
                ],
              );
            },
          ),
        ),
        Padding(
          padding: const EdgeInsets.all(16.0),
          child: SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: () {
                showDialog(
                  context: context,
                  builder: (context) => AlertDialog(
                    backgroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(24),
                    ),
                    title: const Text(
                      'Eliminar',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 18,
                        color: Colors.black,
                      ),
                    ),
                    content: Text(
                      '¿Eliminar ${provider.pendingDeletePhotos.length} elementos seleccionados? Esta acción no se puede deshacer.',
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontSize: 15,
                        color: Colors.black54,
                        height: 1.3,
                      ),
                    ),
                    actionsPadding: const EdgeInsets.only(left: 20, right: 20, bottom: 20, top: 0),
                    actions: [
                      Row(
                        children: [
                          Expanded(
                            child: ElevatedButton(
                              onPressed: () => Navigator.pop(context),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFF5A6270),
                                padding: const EdgeInsets.symmetric(vertical: 14),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(24),
                                ),
                                elevation: 0,
                              ),
                              child: const Text(
                                'Cancelar',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: ElevatedButton.icon(
                              onPressed: () async {
                                Navigator.pop(context);
                                await provider.confirmDeleteAll();
                                setState(() {
                                  _showDeleteView = false;
                                });
                              },
                              icon: const Icon(Icons.delete_outline, color: Colors.white, size: 20),
                              label: const Text(
                                'Eliminar',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFFFF4D4D),
                                padding: const EdgeInsets.symmetric(vertical: 14),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(24),
                                ),
                                elevation: 0,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                );
              },
              icon: const Icon(Icons.delete_outline, color: Colors.white, size: 22),
              label: const Text(
                'Eliminar',
                style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFFF4D4D),
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(24),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  void _checkDeleteLimit(GalleryProvider provider) {
    if (provider.pendingDeletePhotos.length == 30) {
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          backgroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(24),
          ),
          title: const Text(
            'Aviso de rendimiento',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 18,
              color: Colors.black,
            ),
          ),
          content: const Text(
            'Se recomienda ir a la papelera y eliminar las fotos definitivamente para mantener un rendimiento óptimo en la aplicación.',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 15,
              color: Colors.black54,
              height: 1.3,
            ),
          ),
          actionsPadding: const EdgeInsets.only(left: 20, right: 20, bottom: 20, top: 0),
          actions: [
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: () => Navigator.pop(context),
                icon: const Icon(Icons.check_circle_outline, color: Colors.white, size: 20),
                label: const Text(
                  'Continuar',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF7B2FF2),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(24),
                  ),
                  elevation: 0,
                ),
              ),
            ),
          ],
        ),
      );
    }
  }

  void _showAlbumSelectionModal(BuildContext context, GalleryProvider provider) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Padding(
                padding: EdgeInsets.all(16.0),
                child: Text(
                  'Seleccionar Álbum',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.black87,
                  ),
                ),
              ),
              Flexible(
                child: provider.albums.isEmpty
                    ? const Padding(
                        padding: EdgeInsets.all(32.0),
                        child: Text('No hay álbumes disponibles'),
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
                                    color: isSelected ? const Color(0xFF7B2FF2) : Colors.black87,
                                    fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                                    fontSize: 16,
                                  ),
                                );
                              },
                            ),
                            trailing: isSelected
                                ? const Icon(Icons.check_circle, color: Color(0xFF7B2FF2))
                                : null,
                            onTap: () {
                              provider.setAlbum(album);
                              Navigator.pop(context);
                            },
                          );
                        },
                      ),
              ),
              const SizedBox(height: 8),
            ],
          ),
        );
      },
    );
  }
}
