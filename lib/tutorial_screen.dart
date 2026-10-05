import 'package:flutter/material.dart';
import 'theme/app_theme.dart';

class TutorialScreen extends StatelessWidget {
  const TutorialScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final p = AppPalette.of(context);
    return Scaffold(
      backgroundColor: p.canvas,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: p.textPrimary),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          'Tutorial',
          style: TextStyle(color: p.textPrimary, fontWeight: FontWeight.w600),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.all(AppTokens.s16),
        children: [
          const _GestureDemo(),
          const SizedBox(height: AppTokens.s24),
          _TutorialRow(
            icon: Icons.arrow_forward,
            color: p.danger,
            title: 'Desliza a la derecha',
            subtitle: 'Envía la foto a "A eliminar".',
          ),
          _TutorialRow(
            icon: Icons.arrow_back,
            color: p.textPrimary,
            title: 'Desliza a la izquierda',
            subtitle: 'Conserva la foto (no se toca).',
          ),
          _TutorialRow(
            icon: Icons.arrow_upward,
            color: p.accent,
            title: 'Desliza hacia arriba',
            subtitle: 'Mueve la foto al álbum destino.',
          ),
          _TutorialRow(
            icon: Icons.zoom_in,
            color: p.textSecondary,
            title: 'Mantén presionada la tarjeta',
            subtitle: 'Hace zoom para ver el detalle.',
          ),
          _TutorialRow(
            icon: Icons.undo,
            color: p.textSecondary,
            title: 'Botón deshacer',
            subtitle: 'Revierte el último gesto.',
          ),
          _TutorialRow(
            icon: Icons.delete_sweep_outlined,
            color: p.textSecondary,
            title: 'Pestaña "A eliminar"',
            subtitle: 'Revisa lo marcado y bórralo o muévelo en bloque.',
          ),
          const SizedBox(height: AppTokens.s8),
          Container(
            padding: const EdgeInsets.all(AppTokens.s16),
            decoration: BoxDecoration(
              color: p.panel,
              borderRadius: BorderRadius.circular(AppTokens.radiusCard),
              border: Border.all(color: p.hairline, width: 1),
            ),
            child: Row(
              children: [
                Icon(Icons.folder_outlined, color: p.textSecondary, size: 22),
                const SizedBox(width: AppTokens.s12),
                Expanded(
                  child: Text(
                    'Las fotos movidas van a un álbum propio y se ocultan del feed '
                    'principal: solo aparecen si seleccionas ese álbum.',
                    style: TextStyle(color: p.textSecondary, fontSize: 13, height: 1.4),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _TutorialRow extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String title;
  final String subtitle;

  const _TutorialRow({
    required this.icon,
    required this.color,
    required this.title,
    required this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    final p = AppPalette.of(context);
    return Container(
      margin: const EdgeInsets.only(bottom: AppTokens.s12),
      padding: const EdgeInsets.all(AppTokens.s16),
      decoration: BoxDecoration(
        color: p.panel,
        borderRadius: BorderRadius.circular(AppTokens.radiusCard),
        border: Border.all(color: p.hairline, width: 1),
      ),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: p.panelFrost,
              shape: BoxShape.circle,
              border: Border.all(color: p.hairline, width: 1),
            ),
            child: Icon(icon, color: color, size: 22),
          ),
          const SizedBox(width: AppTokens.s16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title,
                    style: TextStyle(color: p.textPrimary, fontSize: 15, fontWeight: FontWeight.w600)),
                const SizedBox(height: 2),
                Text(subtitle, style: TextStyle(color: p.textMuted, fontSize: 13)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Demostración animada: la tarjeta se desliza derecha, izquierda y arriba.
class _GestureDemo extends StatefulWidget {
  const _GestureDemo();

  @override
  State<_GestureDemo> createState() => _GestureDemoState();
}

class _GestureDemoState extends State<_GestureDemo> with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: const Duration(seconds: 7))
      ..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final p = AppPalette.of(context);
    return Container(
      height: 280,
      decoration: BoxDecoration(
        color: p.panel,
        borderRadius: BorderRadius.circular(AppTokens.radiusCard),
        border: Border.all(color: p.hairline, width: 1),
      ),
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, _) {
          final double t = _controller.value;
          Offset offset = Offset.zero;
          double angle = 0;
          String label = '';
          Color labelColor = p.danger;
          IconData labelIcon = Icons.close;

          if (t < 0.33) {
            final double k = t / 0.33;
            offset = Offset(k * 110, 0);
            angle = k * 0.25;
            label = 'ELIMINAR';
            labelColor = p.danger;
            labelIcon = Icons.close;
          } else if (t < 0.66) {
            final double k = (t - 0.33) / 0.33;
            offset = Offset(-k * 110, 0);
            angle = -k * 0.25;
            label = 'CONSERVAR';
            labelColor = p.ctaBg;
            labelIcon = Icons.check;
          } else {
            final double k = (t - 0.66) / 0.34;
            offset = Offset(0, -k * 120);
            label = 'MOVER A ÁLBUM';
            labelColor = p.accent;
            labelIcon = Icons.arrow_upward;
          }

          return Stack(
            alignment: Alignment.center,
            children: [
              Transform.translate(
                offset: offset,
                child: Transform.rotate(
                  angle: angle,
                  child: Container(
                    width: 168,
                    height: 224,
                    decoration: BoxDecoration(
                      color: p.isDark ? const Color(0xFF1E1E1E) : const Color(0xFFEAEAEA),
                      borderRadius: BorderRadius.circular(AppTokens.radiusCard),
                      border: Border.all(color: p.hairline, width: 1),
                    ),
                    child: Icon(Icons.image_outlined, size: 56, color: p.textMuted),
                  ),
                ),
              ),
              Positioned(
                top: 16,
                child: AnimatedOpacity(
                  opacity: label.isEmpty ? 0 : 1,
                  duration: const Duration(milliseconds: 150),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    decoration: BoxDecoration(
                      color: p.canvas.withValues(alpha: 0.6),
                      borderRadius: BorderRadius.circular(AppTokens.radiusButton),
                      border: Border.all(color: labelColor, width: 2),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(labelIcon, color: labelColor, size: 18),
                        const SizedBox(width: 8),
                        Text(
                          label,
                          style: TextStyle(
                            color: labelColor,
                            fontWeight: FontWeight.w700,
                            fontSize: 14,
                            letterSpacing: 1.5,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}
