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
            // Logo superior
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
            const SizedBox(height: 16),
            // Contenedor principal estilo tarjeta (blanco con sombra)
            Expanded(
              child: Container(
                margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8).copyWith(bottom: 24),
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
                    final shouldDelete = direction == DismissDirection.endToStart; // hacia la izquierda
                    if (shouldDelete) {
                      setState(() {
                        deletedCount++;
                      });
                    }
                    await provider.handleSwipe(0, shouldDelete);
                    setState(() {});
                  },
                  background: Container(
                    alignment: Alignment.centerLeft,
                    padding: const EdgeInsets.only(left: 24),
                    color: const Color(0xFF7B2FF2),
                    child: const Icon(Icons.check, color: Colors.white, size: 32),
                  ),
                  secondaryBackground: Container(
                    alignment: Alignment.centerRight,
                    padding: const EdgeInsets.only(right: 24),
                    color: const Color(0xFFFF4D4D),
                    child: const Icon(Icons.close, color: Colors.white, size: 32),
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
                            ? Image.memory(
                                bytes,
                                fit: BoxFit.cover,
                                gaplessPlayback: true,
                              )
                            : Container(color: Colors.grey[300]),
                      ),
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
            // Botón de deshacer (sin lógica aún)
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
            child: ElevatedButton(
              onPressed: () async {
                await provider.confirmDeleteAll();
                setState(() {
                  _showDeleteView = false;
                });
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFFF4D4D),
                padding: const EdgeInsets.symmetric(vertical: 14),
              ),
              child: const Text(
                'Eliminar',
                style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
