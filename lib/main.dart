import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
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