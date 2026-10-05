import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'home_widget_service.dart';
import 'home_screen.dart';
import 'providers/gallery_provider.dart';
import 'providers/settings_provider.dart';
import 'providers/theme_provider.dart';
import 'theme/app_theme.dart';
import 'welcome_screen.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  final themeProvider = ThemeProvider();
  final settingsProvider = SettingsProvider();
  final galleryProvider = GalleryProvider();
  await Future.wait([themeProvider.load(), settingsProvider.load()]);

  // El álbum destino se oculta del feed por defecto.
  galleryProvider.setHiddenAlbum(settingsProvider.moveAlbum);

  // ¿Se abrió tocando el widget? Guardamos la foto a mostrar al frente.
  final initialAssetId = await HomeWidgetService.initialAssetId();
  if (initialAssetId != null) {
    galleryProvider.pendingAssetId = initialAssetId;
  }
  // Si la app ya estaba abierta y tocan el widget, traemos esa foto al frente.
  HomeWidgetService.assetIdClicks().listen((id) {
    if (id == null) return;
    if (galleryProvider.images.isEmpty) {
      galleryProvider.pendingAssetId = id;
    }
    galleryProvider.bringToFront(id);
  });

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider<GalleryProvider>.value(value: galleryProvider),
        ChangeNotifierProvider<ThemeProvider>.value(value: themeProvider),
        ChangeNotifierProvider<SettingsProvider>.value(value: settingsProvider),
      ],
      child: MyApp(
        startAtHome: initialAssetId != null || settingsProvider.onboardingDone,
      ),
    ),
  );
}

class MyApp extends StatelessWidget {
  final bool startAtHome;

  const MyApp({super.key, required this.startAtHome});

  @override
  Widget build(BuildContext context) {
    final themeProvider = context.watch<ThemeProvider>();
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Swipe Gallery',
      theme: AppTheme.light(),
      darkTheme: AppTheme.dark(),
      themeMode: themeProvider.mode,
      home: startAtHome ? const HomeScreen() : const WelcomeScreen(),
    );
  }
}
