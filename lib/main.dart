import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:flutter_card_swiper/flutter_card_swiper.dart';
import 'providers/gallery_provider.dart';
import 'welcome_screen.dart';
void main() {
  runApp(
    ChangeNotifierProvider(
      create: (_) => GalleryProvider(),
      child: const MyApp(),
    ),
  );
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Swipe Gallery',
      theme: ThemeData.dark(),
      home: WelcomeScreen(),
    );
  }
}

class SwipeScreen extends StatelessWidget {
  const SwipeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<GalleryProvider>();

    return Scaffold(
      appBar: AppBar(title: const Text('Limpiar Galería')),
      body: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          ElevatedButton.icon(
            onPressed: () {
              // Respond to button press
            },
            icon: Icon(Icons.arrow_forward, size: 18),
            label: Text("Empezar"),
            style: ElevatedButton.styleFrom(
              padding: EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              textStyle: TextStyle(fontSize: 18),
            ),
          ),
          Expanded(
            child: provider.isLoading
                ? const Center(child: CircularProgressIndicator())
                : provider.images.isEmpty
                    ? const Center(child: Text('¡No hay más fotos!'))
                    : CardSwiper(
                        cardsCount: provider.images.length,
                        cardBuilder: (context, index, percentThresholdX, percentThresholdY) {
                          final asset = provider.images[index];
                          return ClipRRect(
                            borderRadius: BorderRadius.circular(20),
                            child: FutureBuilder(
                              future: asset.file,
                              builder: (context, snapshot) {
                                if (snapshot.connectionState == ConnectionState.done && snapshot.hasData) {
                                  return Image.file(
                                    snapshot.data!,
                                    fit: BoxFit.cover,
                                    width: double.infinity,
                                    height: double.infinity,
                                  );
                                }
                                return const Center(child: CircularProgressIndicator());
                              },
                            ),
                          );
                        },
                        onSwipe: (previousIndex, currentIndex, direction) {
                          bool shouldDelete = direction == CardSwiperDirection.left;
                          context.read<GalleryProvider>().handleSwipe(previousIndex, shouldDelete);
                          return true;
                        },
                      ),
          ),
        ],
      ),
    );
  }
}