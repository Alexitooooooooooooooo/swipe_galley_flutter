import 'package:flutter/material.dart';
import 'package:photo_manager/photo_manager.dart';
import 'package:provider/provider.dart';
import 'home_screen.dart';
import 'providers/gallery_provider.dart';
import 'providers/theme_provider.dart';
import 'theme/app_theme.dart';

class WelcomeScreen extends StatefulWidget {
  const WelcomeScreen({Key? key}) : super(key: key);

  @override
  State<WelcomeScreen> createState() => _WelcomeScreenState();
}

class _WelcomeScreenState extends State<WelcomeScreen> {
  bool isLoading = false;

  Future<void> _handlePress() async {
    setState(() { isLoading = true; });

    // Carga real: pide permisos, obtiene los álbumes y trae el primer lote
    // de imágenes (con sus miniaturas) antes de navegar a la funcionalidad.
    final provider = context.read<GalleryProvider>();
    final bool canContinue = await provider.loadImages();

    if (!mounted) return;
    setState(() { isLoading = false; });

    if (canContinue) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => const HomeScreen()),
      );
    } else {
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Permiso Denegado'),
          content: const Text(
            'No tenemos acceso a tu galería. Si no aparece el popup de permisos, habilítalo desde Ajustes de la app.',
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
  }

  void _showAboutDialog(BuildContext context) {
    final p = AppPalette.of(context);
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(
          'Desarrollado por AlexitoDev',
          textAlign: TextAlign.center,
          style: TextStyle(fontWeight: FontWeight.w600, fontSize: 18, color: p.textPrimary),
        ),
        content: Text(
          'Esta app fue creada por AlexitoDev\n\n¡Gracias por usar Swipe Gallery!',
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 15, color: p.textSecondary, height: 1.4),
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
              child: Text(
                'Cerrar',
                style: TextStyle(color: p.ctaFg, fontWeight: FontWeight.w600, fontSize: 15),
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final p = AppPalette.of(context);
    final tt = Theme.of(context).textTheme;
    final themeProvider = context.watch<ThemeProvider>();

    return Scaffold(
      backgroundColor: p.canvas,
      body: SafeArea(
        child: Stack(
          children: [
            // Radial violet spotlight (signature accent).
            Positioned(
              top: -140,
              left: -80,
              right: -80,
              child: IgnorePointer(
                child: Container(
                  height: 420,
                  decoration: BoxDecoration(gradient: AppTokens.violetSpotlight),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: AppTokens.s24),
              child: Column(
                children: [
                  const SizedBox(height: AppTokens.s8),
                  // Top bar: theme toggle + about (ghost controls)
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      _GhostIconButton(
                        icon: themeProvider.isDark ? Icons.light_mode_outlined : Icons.dark_mode_outlined,
                        tooltip: themeProvider.isDark ? 'Modo claro' : 'Modo oscuro',
                        onTap: themeProvider.toggle,
                      ),
                      const SizedBox(width: AppTokens.s8),
                      _GhostIconButton(
                        icon: Icons.info_outline_rounded,
                        tooltip: 'Acerca de',
                        onTap: () => _showAboutDialog(context),
                      ),
                    ],
                  ),
                  const Spacer(),
                  Image.asset(
                    'assets/logo.png',
                    width: 180,
                    height: 180,
                    fit: BoxFit.contain,
                  ),
                  const SizedBox(height: AppTokens.s24),
                  // Dusk violet wash strip
                  Container(
                    height: 3,
                    width: 140,
                    decoration: BoxDecoration(
                      gradient: AppTokens.duskVioletWash,
                      borderRadius: BorderRadius.circular(AppTokens.radiusButton),
                    ),
                  ),
                  const SizedBox(height: AppTokens.s28),
                  Text(
                    '¡Te damos la',
                    textAlign: TextAlign.center,
                    style: tt.displaySmall?.copyWith(
                      fontWeight: FontWeight.w500,
                      fontSize: 40,
                      height: 1.05,
                      letterSpacing: -1.4,
                      color: p.textPrimary,
                    ),
                  ),
                  Text(
                    'bienvenida a Photo Swipe!',
                    textAlign: TextAlign.center,
                    style: tt.displaySmall?.copyWith(
                      fontWeight: FontWeight.w500,
                      fontSize: 40,
                      height: 1.05,
                      letterSpacing: -1.4,
                      color: p.textPrimary,
                    ),
                  ),
                  const SizedBox(height: AppTokens.s16),
                  Text(
                    'Organiza tu galería. Limpieza inteligente.',
                    textAlign: TextAlign.center,
                    style: tt.bodyLarge?.copyWith(
                      fontSize: 17,
                      color: p.textSecondary,
                      letterSpacing: 0.2,
                    ),
                  ),
                  const Spacer(),
                  _PrimaryCta(
                    isLoading: isLoading,
                    label: 'Empezar',
                    onPressed: _handlePress,
                  ),
                  const SizedBox(height: AppTokens.s28),
                ],
              ),
            ),
          ],
        ),
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

class _PrimaryCta extends StatelessWidget {
  final bool isLoading;
  final String label;
  final VoidCallback? onPressed;

  const _PrimaryCta({
    required this.isLoading,
    required this.label,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    final p = AppPalette.of(context);
    return SizedBox(
      width: double.infinity,
      height: 56,
      child: ElevatedButton(
        onPressed: isLoading ? null : onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: p.ctaBg,
          foregroundColor: p.ctaFg,
          disabledBackgroundColor: p.ctaBg,
          disabledForegroundColor: p.ctaFg,
          elevation: 0,
          shape: const StadiumBorder(),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: [
            if (isLoading)
              SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(color: p.ctaFg, strokeWidth: 2),
              )
            else
              Icon(Icons.arrow_forward, color: p.ctaFg, size: 18),
            const SizedBox(width: 12),
            Text(
              isLoading ? 'Cargando...' : label,
              style: TextStyle(color: p.ctaFg, fontWeight: FontWeight.w600, fontSize: 16, letterSpacing: 0.2),
            ),
          ],
        ),
      ),
    );
  }
}
