import 'dart:io';

import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:provider/provider.dart';
import 'providers/gallery_provider.dart';
import 'providers/settings_provider.dart';
import 'providers/theme_provider.dart';
import 'theme/app_theme.dart';
import 'tutorial_screen.dart';
import 'welcome_screen.dart';

String formatBytes(int bytes) {
  if (bytes <= 0) return '0 B';
  const units = ['B', 'KB', 'MB', 'GB', 'TB'];
  double size = bytes.toDouble();
  int i = 0;
  while (size >= 1024 && i < units.length - 1) {
    size /= 1024;
    i++;
  }
  final str = size >= 100 || i == 0 ? size.toStringAsFixed(0) : size.toStringAsFixed(1);
  return '$str ${units[i]}';
}

String _formatDate(DateTime d) =>
    '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final p = AppPalette.of(context);
    final themeProvider = context.watch<ThemeProvider>();
    final settings = context.watch<SettingsProvider>();
    final gallery = context.watch<GalleryProvider>();

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
          'Configuración',
          style: TextStyle(color: p.textPrimary, fontWeight: FontWeight.w600),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.all(AppTokens.s16),
        children: [
          _SettingsCard(
            title: 'Apariencia',
            children: [
              _SwitchRow(
                title: 'Modo oscuro',
                subtitle: 'Cambia entre tema claro y oscuro',
                value: themeProvider.isDark,
                onChanged: (v) => themeProvider.setMode(v ? ThemeMode.dark : ThemeMode.light),
              ),
            ],
          ),
          _SettingsCard(
            title: 'Interacción',
            children: [
              _SwitchRow(
                title: 'Vibración',
                subtitle: 'Feedback háptico al deslizar',
                value: settings.hapticsEnabled,
                onChanged: settings.setHaptics,
              ),
              _SwitchRow(
                title: 'Sonido',
                subtitle: 'Sonido al deslizar las tarjetas',
                value: settings.soundEnabled,
                onChanged: settings.setSound,
              ),
            ],
          ),
          _SettingsCard(
            title: 'Tutorial',
            children: [
              _ActionRow(
                icon: Icons.school_outlined,
                title: 'Aprende los gestos',
                subtitle: 'Derecha elimina, izquierda conserva, arriba mueve a álbum.',
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const TutorialScreen()),
                ),
              ),
            ],
          ),
          _SettingsCard(
            title: 'Fotos',
            children: [
              _DateFilterRow(gallery: gallery),
              const SizedBox(height: AppTokens.s16),
              _AlbumNameRow(settings: settings),
              const SizedBox(height: AppTokens.s16),
              const _WritePermissionRow(),
            ],
          ),
          _SettingsCard(
            title: 'Meta diaria',
            children: [
              _GoalRow(settings: settings),
            ],
          ),
          _SettingsCard(
            title: 'Estadísticas',
            children: [
              _ValueRow(label: 'Fotos revisadas', value: '${settings.totalReviewed}'),
              _ValueRow(label: 'Fotos eliminadas', value: '${settings.totalDeleted}'),
              _ValueRow(label: 'Espacio liberado', value: formatBytes(settings.freedBytes)),
              const SizedBox(height: AppTokens.s8),
              Align(
                alignment: Alignment.centerRight,
                child: TextButton(
                  onPressed: () => _confirmResetStats(context, settings),
                  child: Text('Reiniciar estadísticas', style: TextStyle(color: p.danger)),
                ),
              ),
            ],
          ),
          _SettingsCard(
            title: 'Acerca de',
            children: [
              const _ValueRow(label: 'Desarrollado por', value: 'AlexitoDev'),
              const _ValueRow(label: 'App', value: 'Swipe Gallery'),
              const _ValueRow(label: 'Versión', value: kAppVersion),
              const SizedBox(height: AppTokens.s8),
              Align(
                alignment: Alignment.centerRight,
                child: TextButton(
                  onPressed: () {
                    settings.resetOnboarding();
                    Navigator.of(context).pushAndRemoveUntil(
                      MaterialPageRoute(builder: (_) => const WelcomeScreen()),
                      (route) => false,
                    );
                  },
                  child: Text(
                    'Ver bienvenida de nuevo',
                    style: TextStyle(color: p.textSecondary),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  void _confirmResetStats(BuildContext context, SettingsProvider settings) {
    final p = AppPalette.of(context);
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Reiniciar estadísticas',
            textAlign: TextAlign.center,
            style: TextStyle(fontWeight: FontWeight.w600, fontSize: 18, color: p.textPrimary)),
        content: Text(
          '¿Seguro que quieres poner en cero las fotos revisadas, eliminadas y el espacio liberado?',
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 15, color: p.textSecondary, height: 1.35),
        ),
        actionsPadding: const EdgeInsets.only(left: 20, right: 20, bottom: 20),
        actions: [
          Row(
            children: [
              Expanded(
                child: SizedBox(
                  height: 48,
                  child: OutlinedButton(
                    onPressed: () => Navigator.pop(context),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: p.textPrimary,
                      side: BorderSide(color: p.hairline, width: 1),
                      shape: const StadiumBorder(),
                    ),
                    child: const Text('Cancelar', style: TextStyle(fontWeight: FontWeight.w600)),
                  ),
                ),
              ),
              const SizedBox(width: AppTokens.s12),
              Expanded(
                child: SizedBox(
                  height: 48,
                  child: ElevatedButton(
                    onPressed: () {
                      settings.resetStats();
                      Navigator.pop(context);
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: p.danger,
                      foregroundColor: Colors.white,
                      elevation: 0,
                      shape: const StadiumBorder(),
                    ),
                    child: const Text('Reiniciar', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _SettingsCard extends StatelessWidget {
  final String title;
  final List<Widget> children;

  const _SettingsCard({required this.title, required this.children});

  @override
  Widget build(BuildContext context) {
    final p = AppPalette.of(context);
    return Container(
      margin: const EdgeInsets.only(bottom: AppTokens.s16),
      padding: const EdgeInsets.all(AppTokens.s16),
      decoration: BoxDecoration(
        color: p.panel,
        borderRadius: BorderRadius.circular(AppTokens.radiusCard),
        border: Border.all(color: p.hairline, width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(left: 4, bottom: AppTokens.s8),
            child: Text(
              title.toUpperCase(),
              style: TextStyle(
                color: p.textMuted,
                fontSize: 12,
                fontWeight: FontWeight.w600,
                letterSpacing: 1.2,
              ),
            ),
          ),
          ...children,
        ],
      ),
    );
  }
}

class _SwitchRow extends StatelessWidget {
  final String title;
  final String subtitle;
  final bool value;
  final ValueChanged<bool> onChanged;

  const _SwitchRow({
    required this.title,
    required this.subtitle,
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final p = AppPalette.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: TextStyle(color: p.textPrimary, fontSize: 16, fontWeight: FontWeight.w500)),
                const SizedBox(height: 2),
                Text(subtitle, style: TextStyle(color: p.textMuted, fontSize: 13)),
              ],
            ),
          ),
          Switch(
            value: value,
            onChanged: onChanged,
            activeThumbColor: p.ctaFg,
            activeTrackColor: p.ctaBg,
          ),
        ],
      ),
    );
  }
}

class _ValueRow extends StatelessWidget {
  final String label;
  final String value;

  const _ValueRow({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    final p = AppPalette.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: TextStyle(color: p.textSecondary, fontSize: 15)),
          Text(value, style: TextStyle(color: p.textPrimary, fontSize: 15, fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }
}

class _DateFilterRow extends StatelessWidget {
  final GalleryProvider gallery;

  const _DateFilterRow({required this.gallery});

  @override
  Widget build(BuildContext context) {
    final p = AppPalette.of(context);
    final DateTimeRange? range = gallery.dateFilter;
    final label = range == null
        ? 'Todas las fotos'
        : '${_formatDate(range.start)}  →  ${_formatDate(range.end)}';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Rango de fechas', style: TextStyle(color: p.textPrimary, fontSize: 16, fontWeight: FontWeight.w500)),
        const SizedBox(height: 4),
        Text(
          range == null ? 'Sin filtro: se muestran todas.' : 'Mostrando solo este rango.',
          style: TextStyle(color: p.textMuted, fontSize: 13),
        ),
        const SizedBox(height: AppTokens.s12),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            color: p.panelFrost,
            borderRadius: BorderRadius.circular(AppTokens.radiusUi),
            border: Border.all(color: p.hairline, width: 1),
          ),
          child: Row(
            children: [
              Icon(Icons.date_range, color: p.textSecondary, size: 20),
              const SizedBox(width: 10),
              Expanded(
                child: Text(label, style: TextStyle(color: p.textPrimary, fontSize: 14)),
              ),
            ],
          ),
        ),
        const SizedBox(height: AppTokens.s12),
        Row(
          children: [
            Expanded(
              child: SizedBox(
                height: 46,
                child: ElevatedButton(
                  onPressed: () => _showFilterSheet(context),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: p.ctaBg,
                    foregroundColor: p.ctaFg,
                    elevation: 0,
                    shape: const StadiumBorder(),
                  ),
                  child: Text('Elegir fecha',
                      style: TextStyle(color: p.ctaFg, fontWeight: FontWeight.w600)),
                ),
              ),
            ),
            if (range != null) ...[
              const SizedBox(width: AppTokens.s12),
              SizedBox(
                height: 46,
                child: OutlinedButton(
                  onPressed: () => gallery.setDateFilter(null),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: p.textPrimary,
                    side: BorderSide(color: p.hairline, width: 1),
                    shape: const StadiumBorder(),
                  ),
                  child: const Text('Quitar', style: TextStyle(fontWeight: FontWeight.w600)),
                ),
              ),
            ],
          ],
        ),
      ],
    );
  }

  int _lastDayOfMonth(int year, int month) => DateTime(year, month + 1, 0).day;

  void _showFilterSheet(BuildContext context) {
    final p = AppPalette.of(context);
    final now = DateTime.now();
    final int y = now.year;
    final int m = now.month;

    final presets = <(String, IconData, DateTimeRange)>[
      (
        'Este mes',
        Icons.calendar_today_outlined,
        DateTimeRange(start: DateTime(y, m, 1), end: DateTime(y, m, _lastDayOfMonth(y, m))),
      ),
      (
        'Mes pasado',
        Icons.calendar_month_outlined,
        DateTimeRange(start: DateTime(y, m - 1, 1), end: DateTime(y, m - 1, _lastDayOfMonth(y, m - 1))),
      ),
      (
        'Últimos 3 meses',
        Icons.date_range_outlined,
        DateTimeRange(start: DateTime(y, m - 2, 1), end: now),
      ),
      (
        'Este año ($y)',
        Icons.event_outlined,
        DateTimeRange(start: DateTime(y, 1, 1), end: DateTime(y, 12, 31)),
      ),
      (
        'Año pasado (${y - 1})',
        Icons.history,
        DateTimeRange(start: DateTime(y - 1, 1, 1), end: DateTime(y - 1, 12, 31)),
      ),
    ];

    showModalBottomSheet<void>(
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
                  'Filtrar por fecha',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600, color: p.textPrimary),
                ),
              ),
              Container(height: 1, color: p.hairline),
              ...presets.map(
                (preset) => ListTile(
                  leading: Icon(preset.$2, color: p.textSecondary),
                  title: Text(preset.$1, style: TextStyle(color: p.textPrimary, fontSize: 16)),
                  onTap: () {
                    Navigator.pop(context);
                    gallery.setDateFilter(preset.$3);
                  },
                ),
              ),
              ListTile(
                leading: Icon(Icons.tune, color: p.textSecondary),
                title: Text('Rango personalizado…',
                    style: TextStyle(color: p.textPrimary, fontSize: 16)),
                subtitle: Text('Elige día de inicio y fin en el calendario',
                    style: TextStyle(color: p.textMuted, fontSize: 12)),
                onTap: () {
                  Navigator.pop(context);
                  _pickCustomRange(context);
                },
              ),
              if (gallery.dateFilter != null)
                ListTile(
                  leading: Icon(Icons.clear, color: p.danger),
                  title: Text('Quitar filtro', style: TextStyle(color: p.danger, fontSize: 16)),
                  onTap: () {
                    Navigator.pop(context);
                    gallery.setDateFilter(null);
                  },
                ),
              const SizedBox(height: AppTokens.s8),
            ],
          ),
        );
      },
    );
  }

  Future<void> _pickCustomRange(BuildContext context) async {
    final now = DateTime.now();
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2000),
      lastDate: DateTime(now.year + 1),
      initialDateRange: gallery.dateFilter,
      helpText: 'Selecciona el rango',
      saveText: 'Aplicar',
    );
    if (picked != null) {
      await gallery.setDateFilter(picked);
    }
  }
}

class _GoalRow extends StatelessWidget {
  final SettingsProvider settings;

  const _GoalRow({required this.settings});

  @override
  Widget build(BuildContext context) {
    final p = AppPalette.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Fotos por día', style: TextStyle(color: p.textPrimary, fontSize: 16, fontWeight: FontWeight.w500)),
        const SizedBox(height: 4),
        Text('Meta para el recordatorio "revisa hoy".',
            style: TextStyle(color: p.textMuted, fontSize: 13)),
        const SizedBox(height: AppTokens.s12),
        Row(
          children: [
            _stepButton(
              p,
              icon: Icons.remove,
              onTap: () => settings.setDailyGoal(settings.dailyGoal - 1),
            ),
            Container(
              width: 72,
              alignment: Alignment.center,
              child: Text(
                '${settings.dailyGoal}',
                style: TextStyle(color: p.textPrimary, fontSize: 20, fontWeight: FontWeight.w600),
              ),
            ),
            _stepButton(
              p,
              icon: Icons.add,
              onTap: () => settings.setDailyGoal(settings.dailyGoal + 1),
            ),
            const Spacer(),
            Text('Hoy: ${settings.reviewedToday}/${settings.dailyGoal}',
                style: TextStyle(color: p.textMuted, fontSize: 13)),
          ],
        ),
      ],
    );
  }

  Widget _stepButton(AppPalette p, {required IconData icon, required VoidCallback onTap}) {
    return Material(
      color: p.panelFrost,
      shape: CircleBorder(side: BorderSide(color: p.hairline, width: 1)),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: SizedBox(
          width: 44,
          height: 44,
          child: Icon(icon, color: p.textPrimary, size: 20),
        ),
      ),
    );
  }
}

class _AlbumNameRow extends StatelessWidget {
  final SettingsProvider settings;

  const _AlbumNameRow({required this.settings});

  @override
  Widget build(BuildContext context) {
    final p = AppPalette.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Álbum destino',
            style: TextStyle(color: p.textPrimary, fontSize: 16, fontWeight: FontWeight.w500)),
        const SizedBox(height: 4),
        Text('A dónde se mueven las fotos con "Mover a álbum".',
            style: TextStyle(color: p.textMuted, fontSize: 13)),
        const SizedBox(height: AppTokens.s12),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            color: p.panelFrost,
            borderRadius: BorderRadius.circular(AppTokens.radiusUi),
            border: Border.all(color: p.hairline, width: 1),
          ),
          child: Row(
            children: [
              Icon(Icons.folder_outlined, color: p.textSecondary, size: 20),
              const SizedBox(width: 10),
              Expanded(
                child: Text(settings.moveAlbum,
                    style: TextStyle(color: p.textPrimary, fontSize: 14)),
              ),
            ],
          ),
        ),
        const SizedBox(height: AppTokens.s12),
        SizedBox(
          width: double.infinity,
          height: 46,
          child: OutlinedButton(
            onPressed: () => _editAlbumName(context),
            style: OutlinedButton.styleFrom(
              foregroundColor: p.textPrimary,
              side: BorderSide(color: p.hairline, width: 1),
              shape: const StadiumBorder(),
            ),
            child: const Text('Cambiar nombre', style: TextStyle(fontWeight: FontWeight.w600)),
          ),
        ),
      ],
    );
  }

  Future<void> _editAlbumName(BuildContext context) async {
    final p = AppPalette.of(context);
    final controller = TextEditingController(text: settings.moveAlbum);
    final result = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Nombre del álbum',
            style: TextStyle(fontWeight: FontWeight.w600, color: p.textPrimary)),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: const InputDecoration(hintText: 'swipe-album'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancelar'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, controller.text),
            child: const Text('Guardar'),
          ),
        ],
      ),
    );
    if (result != null && result.trim().isNotEmpty) {
      await settings.setMoveAlbum(result);
      if (context.mounted) {
        context.read<GalleryProvider>().setHiddenAlbum(result.trim());
      }
    }
    controller.dispose();
  }
}

class _ActionRow extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  const _ActionRow({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final p = AppPalette.of(context);
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppTokens.radiusUi),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Row(
          children: [
            Icon(icon, color: p.textSecondary, size: 22),
            const SizedBox(width: AppTokens.s12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title,
                      style: TextStyle(color: p.textPrimary, fontSize: 16, fontWeight: FontWeight.w500)),
                  const SizedBox(height: 2),
                  Text(subtitle, style: TextStyle(color: p.textMuted, fontSize: 13)),
                ],
              ),
            ),
            Icon(Icons.chevron_right, color: p.textMuted, size: 22),
          ],
        ),
      ),
    );
  }
}

class _WritePermissionRow extends StatefulWidget {
  const _WritePermissionRow();

  @override
  State<_WritePermissionRow> createState() => _WritePermissionRowState();
}

class _WritePermissionRowState extends State<_WritePermissionRow> {
  bool? _granted;

  bool get _supported => Platform.isAndroid;

  @override
  void initState() {
    super.initState();
    _check();
  }

  Future<void> _check() async {
    if (!_supported) {
      if (mounted) setState(() => _granted = null);
      return;
    }
    try {
      final g = await Permission.manageExternalStorage.isGranted;
      if (mounted) setState(() => _granted = g);
    } catch (_) {
      if (mounted) setState(() => _granted = false);
    }
  }

  Future<void> _request() async {
    if (!_supported) return;
    try {
      await Permission.manageExternalStorage.request();
    } catch (_) {
      // Ignoramos; se revalida abajo.
    }
    await _check();
  }

  @override
  Widget build(BuildContext context) {
    final p = AppPalette.of(context);
    final granted = _granted ?? false;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text('Permiso de escritura',
                style: TextStyle(color: p.textPrimary, fontSize: 16, fontWeight: FontWeight.w500)),
            const Spacer(),
            Icon(
              granted ? Icons.check_circle : Icons.error_outline,
              color: granted ? p.textPrimary : p.danger,
              size: 20,
            ),
          ],
        ),
        const SizedBox(height: 4),
        Text(
          !_supported
              ? 'Solo disponible en Android.'
              : granted
                  ? 'Activado: las fotos se mueven sin pedir permiso cada vez.'
                  : 'Desactivado: Android pedirá permiso en cada movimiento. Actívalo para no repetirlo.',
          style: TextStyle(color: p.textMuted, fontSize: 13, height: 1.35),
        ),
        if (_supported && !granted) ...[
          const SizedBox(height: AppTokens.s12),
          OutlinedButton(
            onPressed: _request,
            style: OutlinedButton.styleFrom(
              foregroundColor: p.textPrimary,
              side: BorderSide(color: p.hairline, width: 1),
              shape: const StadiumBorder(),
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            ),
            child: const Text('Conceder permiso permanente',
                style: TextStyle(fontWeight: FontWeight.w600)),
          ),
        ],
      ],
    );
  }
}
